import SwiftUI

struct QueueView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(CoverArtManager.self) private var coverArtManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Currently Playing
                if let current = playerVM.currentSong {
                    Section("Now Playing") {
                        CurrentlyPlayingRow(song: current)
                    }
                }
                
                // Queue
                Section("Up Next") {
                    ForEach(Array(playerVM.queue.enumerated()), id: \.element.id) { index, song in
                        QueueSongRow(
                            song: song,
                            queuePosition: index + 1,
                            onTap: {
                                Task { await playerVM.play(song: song, context: playerVM.queue) }
                            }
                        )
                    }
                }
            }
            .navigationTitle("Queue")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Currently Playing Row

struct CurrentlyPlayingRow: View {
    let song: Song
    // FIX: Swift 6 Environment
    @Environment(CoverArtManager.self) private var coverArtManager
    @Environment(PlayerViewModel.self) private var playerVM
    
    private var coverArt: UIImage? {
        guard let albumId = song.albumId else { return nil }
        // FIX: Explicit ImageContext.list
        return coverArtManager.getAlbumImage(for: albumId, context: ImageContext.list)
    }
    
    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
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
            
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(song.title)
                    .font(DSText.emphasized)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(song.artist ?? "Unknown Artist")
                    .font(DSText.metadata)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, DSLayout.tightGap)
    }
}

// MARK: - Queue Song Row

struct QueueSongRow: View {
    let song: Song
    let queuePosition: Int
    let onTap: () -> Void
    
    // FIX: Swift 6 Environment
    @Environment(CoverArtManager.self) private var coverArtManager
    
    private var coverArt: UIImage? {
        guard let albumId = song.albumId else { return nil }
        // FIX: Explicit ImageContext.list
        return coverArtManager.getAlbumImage(for: albumId, context: ImageContext.list)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSLayout.contentGap) {
                Text("\(queuePosition)")
                    .font(DSText.metadata.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 20, alignment: .center)
                
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
                                .foregroundColor(.secondary)
                        )
                }
                
                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text(song.title)
                        .font(DSText.emphasized)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(song.artist ?? "Unknown Artist")
                        .font(DSText.metadata)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
