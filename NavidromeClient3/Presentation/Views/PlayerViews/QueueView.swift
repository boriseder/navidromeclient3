import SwiftUI

struct QueueView: View {
    // FIX: Swift 6 Environment
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(CoverArtManager.self) private var coverArtManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(playerVM.queue) { song in
                    Text(song.title)
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
