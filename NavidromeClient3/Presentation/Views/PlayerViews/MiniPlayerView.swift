//
//  MiniPlayerView.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Compiler Errors & Component Usage
//

import SwiftUI

struct MiniPlayerView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(CoverArtManager.self) private var coverArtManager
    
    @State private var showFullScreen = false
    @State private var isDragging = false
    
    var body: some View {
        if let song = playerVM.currentSong {
            VStack(spacing: 0) {
                // Progress Bar
                ProgressBarView(playerVM: playerVM, isDragging: $isDragging)
                
                HStack(spacing: 12) {
                    // Cover Art
                    AlbumImageView(albumId: song.albumId ?? "", size: 48)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(radius: 4)
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text(song.artist ?? "Unknown Artist")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Controls
                    HStack(spacing: 16) {
                        // FIX: Use standard HeartButton initializer
                        HeartButton(song: song)
                            .font(.system(size: 20)) // Adjust size manually since we don't have .miniPlayer
                        
                        // Play/Pause
                        Button {
                            playerVM.togglePlayPause()
                        } label: {
                            ZStack {
                                if playerVM.isPlaying {
                                    Image(systemName: "pause.fill")
                                } else {
                                    Image(systemName: "play.fill")
                                }
                            }
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    // FIX: Use standard DynamicMusicBackground without arguments
                    DynamicMusicBackground()
                        .overlay(Color.black.opacity(0.3)) // Add slight dimming for legibility
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    showFullScreen = true
                }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height < -50 {
                                showFullScreen = true // Swipe Up -> Expand
                            } else if value.translation.height > 50 {
                                playerVM.pause() // Swipe Down -> Pause
                            }
                        }
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 0))
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
            .fullScreenCover(isPresented: $showFullScreen) {
                FullScreenPlayer()
            }
        }
    }
}

// MARK: - Progress Bar Component

struct ProgressBarView: View {
    var playerVM: PlayerViewModel
    @Binding var isDragging: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 2)
                
                // Progress
                Rectangle()
                    .fill(Color.white)
                    .frame(width: max(0, geometry.size.width * progressPercentage), height: 2)
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
