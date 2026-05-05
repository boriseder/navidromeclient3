//
//  QueueView.swift
//  NavidromeClient
//
//  REFACTORED: Step 3 — ImageCacheActor
//  Row subviews load cover art via @State + .task
//

import SwiftUI

struct QueueView: View {
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(CoverArtManager.self) var coverArtManager
    @Environment(\.dismiss) private var dismiss

    private var currentPlaylist: [Song] { playerVM.playlistManager.currentPlaylist }
    private var currentIndex: Int { playerVM.playlistManager.currentIndex }

    private var upNextSongs: [Song] {
        let total = currentPlaylist.count
        guard total > 0, currentIndex < total else { return [] }
        return Array(currentPlaylist[(currentIndex + 1)...])
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
                    Button("Done") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Shuffle Queue") { shuffleUpNext() }
                        Button("Clear Queue")   { clearQueue() }
                        Button("Repeat: \(repeatModeText)") { playerVM.toggleRepeat() }
                    } label: {
                        Image(systemName: "ellipsis").foregroundStyle(.white)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var queueContent: some View {
        ScrollViewReader { proxy in
            List {
                if let currentSong = playerVM.currentSong {
                    Section {
                        CurrentlyPlayingRow(song: currentSong)
                    } header: {
                        Text("Now Playing").foregroundStyle(.white.opacity(0.8))
                    }
                    .listRowBackground(Color.clear)
                }

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
                            Text("Up Next (\(upNextSongs.count))").foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            if playerVM.isShuffling {
                                Image(systemName: "shuffle").foregroundStyle(.green).font(.caption)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    QueueInfoView(
                        totalSongs: currentPlaylist.count,
                        remainingSongs: upNextSongs.count,
                        totalDuration: calculateTotalDuration()
                    )
                } header: {
                    Text("Queue Info").foregroundStyle(.white.opacity(0.8))
                }
                .listRowBackground(Color.clear)

                Color.clear.frame(height: DSLayout.miniPlayerHeight).listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.1))
                    withAnimation { proxy.scrollTo("song-\(currentIndex + 1)", anchor: .top) }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyQueueView: some View {
        VStack(spacing: DSLayout.screenGap) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.6))
            Text("No songs in queue")
                .font(DSText.itemTitle).foregroundStyle(.white)
            Text("Start playing music to see your queue")
                .font(DSText.body).foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(DSLayout.screenPadding)
    }

    private func jumpToSong(at index: Int) {
        Task { await playerVM.jumpToSong(at: index) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func moveUpNextSongs(from source: IndexSet, to destination: Int) {
        let sourceIndices = source.map { currentIndex + 1 + $0 }
        Task { await playerVM.moveQueueSongs(from: sourceIndices, to: currentIndex + 1 + destination) }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func deleteUpNextSongs(at offsets: IndexSet) {
        let indices = offsets.map { currentIndex + 1 + $0 }
        Task { await playerVM.removeQueueSongs(at: indices) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func shuffleUpNext() {
        playerVM.shuffleUpNext()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func clearQueue() {
        playerVM.clearQueue()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    private func calculateTotalDuration() -> Int {
        currentPlaylist.reduce(0) { $0 + ($1.duration ?? 0) }
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
    @Environment(CoverArtManager.self) var coverArtManager
    @Environment(PlayerViewModel.self) var playerVM

    @State private var cover: UIImage? = nil

    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
            ZStack {
                if let cover = cover {
                    Image(uiImage: cover)
                        .resizable().scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                } else {
                    RoundedRectangle(cornerRadius: DSCorners.element)
                        .fill(.ultraThinMaterial)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "music.note").foregroundStyle(.white.opacity(0.6))
                        )
                }

                if playerVM.isPlaying {
                    RoundedRectangle(cornerRadius: DSCorners.element)
                        .fill(.black.opacity(0.4))
                        .frame(width: 50, height: 50)
                        .overlay(
                            EqualizerBars(isActive: true, accentColor: .white).scaleEffect(0.6)
                        )
                }
            }
            .task(id: song.albumId) {
                guard let albumId = song.albumId else { cover = nil; return }
                if let cached = await coverArtManager.imageCache.cachedImage(
                    for: albumId, type: .album, size: ImageContext.list.size
                ) { cover = cached; return }
                cover = await coverArtManager.loadAlbumImage(for: albumId, context: .list)
            }

            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(song.title)
                    .font(DSText.emphasized).foregroundStyle(.white).lineLimit(1)
                Text(song.artist ?? "Unknown Artist")
                    .font(DSText.metadata).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
            }

            Spacer()

            VStack(spacing: DSLayout.tightGap) {
                Image(systemName: "speaker.wave.2.fill").foregroundStyle(.green).font(DSText.metadata)
                Text("Now Playing").font(.caption2).foregroundStyle(.green)
            }
        }
        .padding(.vertical, DSLayout.tightGap)
    }
}

// MARK: - Queue Song Row

struct QueueSongRow: View {
    let song: Song
    let queuePosition: Int
    let onTap: @MainActor () -> Void

    @Environment(CoverArtManager.self) var coverArtManager
    @State private var cover: UIImage? = nil

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSLayout.contentGap) {
                Text("\(queuePosition)")
                    .font(DSText.metadata.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 20, alignment: .center)

                Group {
                    if let cover = cover {
                        Image(uiImage: cover)
                            .resizable().scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
                    } else {
                        RoundedRectangle(cornerRadius: DSCorners.tight)
                            .fill(.ultraThinMaterial)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.caption).foregroundStyle(.white.opacity(0.6))
                            )
                    }
                }
                .task(id: song.albumId) {
                    guard let albumId = song.albumId else { cover = nil; return }
                    if let cached = await coverArtManager.imageCache.cachedImage(
                        for: albumId, type: .album, size: ImageContext.list.size
                    ) { cover = cached; return }
                    cover = await coverArtManager.loadAlbumImage(for: albumId, context: .list)
                }

                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text(song.title)
                        .font(DSText.emphasized).foregroundStyle(.white).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(song.artist ?? "Unknown Artist")
                        .font(DSText.metadata).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let duration = song.duration {
                    Text(formatDuration(duration))
                        .font(DSText.metadata.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Queue Info View

struct QueueInfoView: View {
    let totalSongs: Int
    let remainingSongs: Int
    let totalDuration: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text("\(totalSongs)").font(DSText.prominent).foregroundStyle(.white)
                Text("Total Songs").font(DSText.metadata).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            VStack(alignment: .center, spacing: DSLayout.tightGap) {
                Text("\(remainingSongs)").font(DSText.prominent).foregroundStyle(.white)
                Text("Up Next").font(DSText.metadata).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: DSLayout.tightGap) {
                Text(formatTotalDuration(totalDuration))
                    .font(DSText.prominent.monospacedDigit()).foregroundStyle(.white)
                Text("Total Time").font(DSText.metadata).foregroundStyle(.white.opacity(0.7))
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

    private func formatTotalDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0
            ? String(format: "%d:%02d:00", hours, minutes)
            : String(format: "%d:00", minutes)
    }
}
