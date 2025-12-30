//
//  QueueView.swift
//  NavidromeClient
//
//  Complete Queue Management with native iOS design
//

import SwiftUI

struct QueueView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var coverArtManager: CoverArtManager
    @Environment(\.dismiss) private var dismiss
    
    private var currentPlaylist: [Song] {
        playerVM.playlistManager.currentPlaylist
    }
    
    private var currentIndex: Int {
        playerVM.playlistManager.currentIndex
    }
    
    private var upNextSongs: [Song] {
        let totalSongs = currentPlaylist.count
        guard totalSongs > 0, currentIndex < totalSongs else { return [] }
        
        let nextIndex = currentIndex + 1
        return Array(currentPlaylist[nextIndex..<totalSongs])
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                
                if currentPlaylist.isEmpty {
                    emptyQueueView
                } else {
                    queueContent
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.automatic)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Shuffle Queue") {
                            shuffleUpNext()
                        }
                        
                        Button("Clear Queue") {
                            clearQueue()
                        }
                        
                        Button("Repeat: \(repeatModeText)") {
                            playerVM.toggleRepeat()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Queue Content
    
    @ViewBuilder
    private var queueContent: some View {
        ScrollViewReader { proxy in
            List {
                // Currently Playing Section
                if let currentSong = playerVM.currentSong {
                    Section {
                        CurrentlyPlayingRow(song: currentSong)
                    } header: {
                        Text("Now Playing")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .listRowBackground(Color.clear)
                }
                
                // Up Next Section
                if !upNextSongs.isEmpty {
                    Section {
                        ForEach(upNextSongs.indices, id: \.self) { relativeIndex in
                            let actualIndex = currentIndex + 1 + relativeIndex
                            let song = upNextSongs[relativeIndex]
                            
                            QueueSongRow(
                                song: song,
                                queuePosition: relativeIndex + 1,
                                onTap: { jumpToSong(at: actualIndex) }
                            )
                            .id("song-\(actualIndex)")
                        }
                        .onMove(perform: moveUpNextSongs)
                        .onDelete(perform: deleteUpNextSongs)
                    } header: {
                        HStack {
                            Text("Up Next (\(upNextSongs.count))")
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            if playerVM.isShuffling {
                                Image(systemName: "shuffle")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                
                // Queue Info
                Section {
                    QueueInfoView(
                        totalSongs: currentPlaylist.count,
                        remainingSongs: upNextSongs.count,
                        totalDuration: calculateTotalDuration()
                    )
                } header: {
                    Text("Queue Info")
                        .foregroundColor(.white.opacity(0.8))
                }
                .listRowBackground(Color.clear)
                
                // Bottom spacing for mini player
                Color.clear
                    .frame(height: DSLayout.miniPlayerHeight)
                    .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .onAppear {
                // Scroll to current song when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo("song-\(currentIndex + 1)", anchor: .top)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyQueueView: some View {
        VStack(spacing: DSLayout.screenGap) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No songs in queue")
                .font(DSText.itemTitle)
                .foregroundColor(.white)
            
            Text("Start playing music to see your queue")
                .font(DSText.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(DSLayout.screenPadding)
    }
    
    // MARK: - Queue Management Actions
    
    private func jumpToSong(at index: Int) {
        Task {
            await playerVM.jumpToSong(at: index)
        }
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func moveUpNextSongs(from source: IndexSet, to destination: Int) {
        // Convert relative indices to absolute playlist indices
        let sourceIndices = source.map { currentIndex + 1 + $0 }
        let destIndex = currentIndex + 1 + destination
        
        Task {
            await playerVM.moveQueueSongs(from: sourceIndices, to: destIndex)
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func deleteUpNextSongs(at offsets: IndexSet) {
        // Convert relative indices to absolute playlist indices
        let indicesToDelete = offsets.map { currentIndex + 1 + $0 }
        
        Task {
            await playerVM.removeQueueSongs(at: indicesToDelete)
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func shuffleUpNext() {
        Task {
            await playerVM.shuffleUpNext()
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func clearQueue() {
        Task {
            await playerVM.clearQueue()
        }
        
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    // MARK: - Helper Methods
    
    private func calculateTotalDuration() -> Int {
        return currentPlaylist.reduce(0) { total, song in
            total + (song.duration ?? 0)
        }
    }
    
    private var repeatModeText: String {
        switch playerVM.repeatMode {
        case .off: return "Off"
        case .all: return "All"
        case .one: return "One"
        }
    }
}

// MARK: - Currently Playing Row

struct CurrentlyPlayingRow: View {
    let song: Song
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var playerVM: PlayerViewModel
    
    private var coverArt: UIImage? {
        guard let albumId = song.albumId else { return nil }
        return coverArtManager.getAlbumImage(for: albumId, context: .list)
    }
    
    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
            // Album Art with playing indicator
            ZStack {
                if let coverArt = coverArt {
                    Image(uiImage: coverArt)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                } else {
                    RoundedRectangle(cornerRadius: DSCorners.element)
                        .fill(.ultraThinMaterial)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.white.opacity(0.6))
                        )
                }
                
                // Playing indicator overlay
                if playerVM.isPlaying {
                    RoundedRectangle(cornerRadius: DSCorners.element)
                        .fill(.black.opacity(0.4))
                        .frame(width: 50, height: 50)
                        .overlay(
                            EqualizerBars(isActive: true, accentColor: .white)
                                .scaleEffect(0.6)
                        )
                }
            }
            
            // Song Info
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(song.title)
                    .font(DSText.emphasized)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(song.artist ?? "Unknown Artist")
                    .font(DSText.metadata)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Current playing indicator
            VStack(spacing: DSLayout.tightGap) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.green)
                    .font(DSText.metadata)
                
                Text("Now Playing")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, DSLayout.tightGap)
    }
}

// MARK: - Queue Song Row

struct QueueSongRow: View {
    let song: Song
    let queuePosition: Int
    let onTap: () -> Void
    
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    private var coverArt: UIImage? {
        guard let albumId = song.albumId else { return nil }
        return coverArtManager.getAlbumImage(for: albumId, context: .list)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSLayout.contentGap) {
                // Queue position number
                Text("\(queuePosition)")
                    .font(DSText.metadata.monospacedDigit())
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 20, alignment: .center)
                
                // Album Art
                if let coverArt = coverArt {
                    Image(uiImage: coverArt)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
                } else {
                    RoundedRectangle(cornerRadius: DSCorners.tight)
                        .fill(.ultraThinMaterial)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        )
                }
                
                // Song Info
                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text(song.title)
                        .font(DSText.emphasized)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(song.artist ?? "Unknown Artist")
                        .font(DSText.metadata)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Duration
                if let duration = song.duration {
                    Text(formatDuration(duration))
                        .font(DSText.metadata.monospacedDigit())
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Queue Info View

struct QueueInfoView: View {
    let totalSongs: Int
    let remainingSongs: Int
    let totalDuration: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.elementGap) {
            HStack {
                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text("\(totalSongs)")
                        .font(DSText.prominent)
                        .foregroundColor(.white)
                    Text("Total Songs")
                        .font(DSText.metadata)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: DSLayout.tightGap) {
                    Text("\(remainingSongs)")
                        .font(DSText.prominent)
                        .foregroundColor(.white)
                    Text("Up Next")
                        .font(DSText.metadata)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: DSLayout.tightGap) {
                    Text(formatTotalDuration(totalDuration))
                        .font(DSText.prominent.monospacedDigit())
                        .foregroundColor(.white)
                    Text("Total Time")
                        .font(DSText.metadata)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(DSLayout.contentPadding)
            .background(
                RoundedRectangle(cornerRadius: DSCorners.content)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSCorners.content)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    private func formatTotalDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return String(format: "%d:%02d:00", hours, minutes)
        } else {
            return String(format: "%d:00", minutes)
        }
    }
}
