import SwiftUI

struct MiniPlayerView: View {
    // FIX: Swift 6 Environment
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(AudioSessionManager.self) private var audioSessionManager
    @Environment(CoverArtManager.self) private var coverArtManager
    
    @State private var showFullScreen = false
    
    var body: some View {
        if let song = playerVM.currentSong {
            VStack {
                HStack {
                    Text(song.title)
                    Spacer()
                    Button(action: { playerVM.togglePlayPause() }) {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
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


// MARK: - Progress Bar unchanged

struct ProgressBarView: View {
    @ObservedObject var playerVM: PlayerViewModel
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

// MARK: - Album Art unchanged

struct AlbumArtView: View {
    let cover: UIImage?
    
    var body: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundStyle(.gray)
                    )
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
