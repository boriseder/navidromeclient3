//
//  MiniPlayerView.swift
//  NavidromeClient
//
//  Modern UI/UX Redesign - iOS 17+
//

import SwiftUI
import Observation

struct MiniPlayerView: View {
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(AudioSessionManager.self) var audioSessionManager
    @Environment(CoverArtManager.self) var coverArtManager
    
    @State private var showFullScreen = false
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    @State private var isPressed = false
    
    var body: some View {
        if let song = playerVM.currentSong {
            VStack(spacing: 0) {
                // Ultra-thin modern progress bar
                ModernProgressBar(playerVM: playerVM, isDragging: $isDragging)
                
                HStack(spacing: 16) {
                    // Album art with modern styling
                    ModernAlbumArt(
                        cover: song.albumId.flatMap { albumId in
                            coverArtManager.getAlbumImage(for: albumId, context: .miniPlayer)
                        }
                    )
                    
                    // Song info with better typography
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        if let artist = song.artist {
                            Text(artist)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Control buttons with modern interaction
                    HStack(spacing: 20) {
                        HeartButton.miniPlayer(song: song)
                        
                        PlayPauseButton(
                            isPlaying: playerVM.isPlaying,
                            isLoading: playerVM.isLoading
                        ) {
                            playerVM.togglePlayPause()
                        }
                        
                        Button {
                            Task {
                                await playerVM.playNext()
                            }
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    ModernBackgroundView(
                        albumId: song.albumId,
                        coverArtManager: coverArtManager
                    )
                )
                .contentShape(Rectangle())
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .offset(y: dragOffset)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if abs(value.translation.height) > abs(value.translation.width) {
                                dragOffset = value.translation.height
                                if value.translation.height > 10 {
                                    isPressed = false
                                }
                            } else if value.translation.height == 0 {
                                isPressed = true
                            }
                        }
                        .onEnded { value in
                            isPressed = false
                            
                            if value.translation.height < -80 {
                                // Swipe up - open full screen
                                showFullScreen = true
                                dragOffset = 0
                            } else if value.translation.height > 100 {
                                // Swipe down - close player
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    dragOffset = 300
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    playerVM.stop()
                                    dragOffset = 0
                                }
                            } else if abs(value.translation.height) < 10 && abs(value.translation.width) < 10 {
                                // Tap - open full screen
                                showFullScreen = true
                                dragOffset = 0
                            } else {
                                // Snap back
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
            .task(id: song.albumId) {
                if let albumId = song.albumId {
                    _ = await coverArtManager.loadAlbumImage(for: albumId, context: .miniPlayer)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .fullScreenCover(isPresented: $showFullScreen) {
                FullScreenPlayerView()
            }
        }
    }
}

// MARK: - Modern Progress Bar

struct ModernProgressBar: View {
    var playerVM: PlayerViewModel
    @Binding var isDragging: Bool
    @State private var localProgress: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track - ultra thin
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 3)
                
                // Progress with gradient
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * (isDragging ? localProgress : progressPercentage), height: 3)
                    .animation(isDragging ? nil : .linear(duration: 0.1), value: progressPercentage)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let progress = max(0, min(value.location.x / geometry.size.width, 1))
                        localProgress = progress
                        let newTime = progress * playerVM.duration
                        playerVM.seek(to: newTime)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 3)
    }
    
    private var progressPercentage: Double {
        guard playerVM.duration > 0 else { return 0 }
        return playerVM.currentTime / playerVM.duration
    }
}

// MARK: - Modern Album Art

struct ModernAlbumArt: View {
    let cover: UIImage?
    
    var body: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Play/Pause Button

struct PlayPauseButton: View {
    let isPlaying: Bool
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.primary)
                } else {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .disabled(isLoading)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Modern Background

struct ModernBackgroundView: View {
    let albumId: String?
    let coverArtManager: CoverArtManager
    
    var body: some View {
        ZStack {
            // Material blur background
            if let albumId = albumId,
               let cover = coverArtManager.getAlbumImage(for: albumId, context: .miniPlayer) {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 50)
                    .opacity(0.3)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            // Adaptive background material
            Rectangle()
                .fill(.ultraThinMaterial)
        }
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
