//
//  MiniPlayerView.swift
//  NavidromeClient
//

import SwiftUI

struct MiniPlayerView: View {
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(CoverArtManager.self) var coverArtManager

    @State private var showFullScreen = false
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    @State private var coverImage: UIImage?

    private let playerHeight: CGFloat = 68

    var body: some View {
        if let song = playerVM.currentSong {
            HStack(spacing: 0) {
                
                // ── Album art: flush left, full height ──────────────────
                Group {
                    if let img = coverImage {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            Color.white.opacity(0.1)
                            Image(systemName: "music.note")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .frame(width: playerHeight, height: playerHeight)
                // Left corners round, right corners square — clips to pill left edge
                .onTapGesture { showFullScreen = true }
                
                // ── Song info + controls ─────────────────────────────────
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(song.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if let artist = song.artist {
                            Text(artist)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    .contentShape(Rectangle())
                    .onTapGesture { showFullScreen = true }
                    
                    // prev / play / next
                    HStack(spacing: 4) {
                        miniButton("backward.fill", size: 13) {
                            Task { await playerVM.playPrevious() }
                        }
                        playPauseButton
                        miniButton("forward.fill", size: 13) {
                            Task { await playerVM.playNext() }
                        }
                    }
                    .padding(.trailing, 12)
                }
                .frame(maxWidth: .infinity)
                .background {
                    // Blurred cover behind text+controls area
                    ZStack {
                        if let img = coverImage {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)   // ← before frame
                                .frame(maxWidth: .infinity, maxHeight: playerHeight)
                                .clipped()                          // ← contain the overflow
                                .blur(radius: 3)
                                .opacity(1)
                        }
                        // Dark base so text is always readable
                        Color.black.opacity(0.55)
                        // Frosted glass on top
                        Rectangle().fill(.ultraThinMaterial).opacity(0.6)
                    }
                    .clipped()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                }
            }
            .frame(height: playerHeight)
            .overlay(alignment: .bottom) {
                ProgressLineView(
                    progress: playerVM.duration > 0
                    ? playerVM.currentTime / playerVM.duration
                    : 0
                )
            }
            .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 6)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
            .task(id: song.id) { await loadCover(albumId: song.albumId) }
            .fullScreenCover(isPresented: $showFullScreen) {
                FullScreenPlayerView()
            }
            .contentShape(Rectangle())

        }
    }

    // MARK: - Buttons

    @ViewBuilder
    private var playPauseButton: some View {
        Button { playerVM.togglePlayPause() } label: {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 38, height: 38)
                if playerVM.isLoading {
                    ProgressView().scaleEffect(0.7).tint(.white)
                } else {
                    Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .disabled(playerVM.isLoading)
        .buttonStyle(ScaleButtonStyle())
    }

    private func miniButton(_ name: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 34, height: 38)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Cover loading

    private func loadCover(albumId: String?) async {
        guard let albumId else { coverImage = nil; return }
        if let cached = await coverArtManager.imageCache.cachedImage(
            for: albumId, type: .album, size: ImageContext.miniPlayer.size
        ) {
            coverImage = cached; return
        }
        coverImage = await coverArtManager.loadAlbumImage(for: albumId, context: .miniPlayer)
    }
}

private struct ProgressLineView: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(height: 2)
                Rectangle()
                    .fill(.white.opacity(0.6))
                    .frame(width: geo.size.width * progress, height: 2)
                    .animation(.linear(duration: 0.1), value: progress)
            }
        }
        .frame(height: 2)
        .allowsHitTesting(false)  // 👈 key — it's display-only
    }
}

// MARK: - Progress Bar (2px flush bottom)

struct MiniProgressBar: View {
    var playerVM: PlayerViewModel
    @Binding var isDragging: Bool
    @State private var localProgress: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(height: 2)
                Rectangle()
                    .fill(.white.opacity(0.7))
                    .frame(width: geo.size.width * (isDragging ? localProgress : progress), height: 2)
                    .animation(isDragging ? nil : .linear(duration: 0.1), value: progress)
            }
            .contentShape(Rectangle().size(.init(width: geo.size.width, height: 20)).offset(y: -9))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        isDragging = true
                        localProgress = max(0, min(v.location.x / geo.size.width, 1))
                        playerVM.seek(to: localProgress * playerVM.duration)
                    }
                    .onEnded { _ in isDragging = false }
            )
        }
        .frame(height: 2)
    }

    private var progress: Double {
        guard playerVM.duration > 0 else { return 0 }
        return playerVM.currentTime / playerVM.duration
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
