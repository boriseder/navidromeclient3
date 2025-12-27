import SwiftUI

struct MiniPlayerView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(AudioSessionManager.self) private var audioSessionManager
    @Environment(CoverArtManager.self) private var coverArtManager
    
    @State private var showFullScreen = false
    
    var body: some View {
        if let song = playerVM.currentSong {
            VStack(spacing: 0) {
                // Progress Bar (Custom)
                ProgressBarView(playerVM: playerVM, isDragging: .constant(false))
                
                HStack {
                    AlbumImageView(albumId: song.albumId ?? "", size: 50)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    VStack(alignment: .leading) {
                        Text(song.title)
                            .lineLimit(1)
                            .font(.subheadline)
                        Text(song.artist ?? "")
                            .lineLimit(1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { playerVM.togglePlayPause() }) {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    .padding(.trailing)
                }
                .padding(8)
                .background(DSColor.surfaceLight)
                .onTapGesture {
                    showFullScreen = true
                }
            }
            .fullScreenCover(isPresented: $showFullScreen) {
                FullScreenPlayer()
            }
        }
    }
}

// MARK: - Progress Bar

struct ProgressBarView: View {
    // FIX: Using Observable directly, not ObservedObject
    let playerVM: PlayerViewModel
    @Binding var isDragging: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(height: 2)
                
                // Spotify green progress
                Rectangle()
                    .fill(Color.green)
                    .frame(width: geometry.size.width * progressPercentage, height: 2)
                    .animation(isDragging ? nil : .linear(duration: 0.1), value: progressPercentage)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let progress = max(0, min(value.location.x / geometry.size.width, 1))
                        let newTime = progress * playerVM.duration
                        playerVM.seek(to: newTime)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 2)
    }
    
    private var progressPercentage: Double {
        guard playerVM.duration > 0 else { return 0 }
        return playerVM.currentTime / playerVM.duration
    }
}
