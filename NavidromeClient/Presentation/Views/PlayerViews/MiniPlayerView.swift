//
//  MiniPlayerView.swift - FIXED: Use CoverArtManager Directly
//  NavidromeClient
//
//   FIXED: Removed dependency on playerVM.coverArt
//   CLEAN: Direct CoverArtManager integration
//   CONSISTENT: Single source of truth for cover art
//

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var audioSessionManager: AudioSessionManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    @State private var showFullScreen = false
    @State private var isDragging = false
    
    var body: some View {
        if let song = playerVM.currentSong {
            VStack(spacing: 0) {
                ProgressBarView(playerVM: playerVM, isDragging: $isDragging)
                
                HStack(spacing: 12) {
                    HStack(spacing: 12) {
                        AlbumArtView(
                            cover: song.albumId.flatMap { albumId in
                                coverArtManager.getAlbumImage(for: albumId, context: .miniPlayer)
                            }
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            
                            if let artist = song.artist {
                                Text(artist)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        HeartButton.miniPlayer(song: song)
                        
                        Button {
                            playerVM.togglePlayPause()
                        } label: {
                            if playerVM.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 32, height: 32)
                                    .tint(.white)
                            } else {
                                Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                            }
                        }
                        .disabled(playerVM.isLoading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        if let albumId = song.albumId,
                           let cover = coverArtManager.getAlbumImage(for: albumId, context: .miniPlayer) {
                            Image(uiImage: cover)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 40)
                                .opacity(0.7)
                                .clipped()
                        }
                        
                        Color.black.opacity(0.6)
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    showFullScreen = true
                }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height < -50 {
                                showFullScreen = true
                            } else if value.translation.height > 50 {
                                playerVM.stop()
                            }
                        }
                )
            }
            .task(id: song.albumId) {
                if let albumId = song.albumId {
                    _ = await coverArtManager.loadAlbumImage(for: albumId, context: .miniPlayer)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 0))
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: -2)
            .fullScreenCover(isPresented: $showFullScreen) {
                FullScreenPlayerView()
                    .environmentObject(playerVM)
                    .environmentObject(audioSessionManager)
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
