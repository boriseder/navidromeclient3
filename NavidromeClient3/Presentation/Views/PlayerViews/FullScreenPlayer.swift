//
//  FullScreenPlayer.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Frame Dimensions & Restored UI Parity
//

import SwiftUI
import AVKit

struct FullScreenPlayer: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(CoverArtManager.self) private var coverArtManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingQueue = false
    @State private var isFavorite = false
    
    // Gesture State
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        @Bindable var bPlayer = player
        
        GeometryReader { geometry in
            // FIX: Ensure we have valid dimensions before calculating
            let screenWidth = geometry.size.width
            let safeAreaTop = geometry.safeAreaInsets.top
            
            VStack(spacing: 0) {
                // 1. Header (Dismiss + Queue)
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text(player.currentSong?.album ?? "Now Playing")
                        .font(.subheadline)
                        .bold()
                        .lineLimit(1)
                        .opacity(0.8)
                    
                    Spacer()
                    
                    Button {
                        showingQueue = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.top, safeAreaTop > 0 ? safeAreaTop : 20)
                
                Spacer()
                
                // 2. Stacked Art with Gestures
                // FIX: Pass valid width to the subview
                StackedAlbumArtView(
                    currentSong: player.currentSong,
                    queue: player.queue,
                    currentIndex: player.currentIndex,
                    screenWidth: screenWidth
                )
                .frame(height: max(0, screenWidth - 40)) // Safety check
                
                Spacer()
                
                // 3. Metadata & Controls
                VStack(spacing: 24) {
                    // Title & Heart
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(player.currentSong?.title ?? "Not Playing")
                                .font(.title2.bold())
                                .lineLimit(1)
                                .foregroundStyle(.white)
                            
                            Text(player.currentSong?.artist ?? "Unknown Artist")
                                .font(.body)
                                .lineLimit(1)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Button {
                            isFavorite.toggle()
                            // TODO: Call FavoritesManager
                        } label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundStyle(isFavorite ? .green : .white.opacity(0.7))
                        }
                    }
                    
                    // Scrubber
                    VStack(spacing: 8) {
                        Slider(value: $bPlayer.currentTime, in: 0...max(1, player.duration)) { editing in
                            player.isScrubbing = editing
                            if !editing { player.seek(to: player.currentTime) }
                        }
                        .tint(.white)
                        .onAppear {
                            // FIX: Ensure slider thumb image is visible if needed
                            let circle = UIImage(systemName: "circle.fill")
                            UISlider.appearance().setThumbImage(circle, for: .normal)
                        }
                        
                        HStack {
                            Text(formatTime(player.currentTime))
                            Spacer()
                            Text(formatTime(player.duration))
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                    }
                    
                    // Transport Controls
                    HStack(spacing: 0) {
                        Button { player.toggleShuffle() } label: {
                            Image(systemName: "shuffle")
                                .font(.title3)
                                .foregroundStyle(player.isShuffleEnabled ? .green : .white)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button { player.previousTrack() } label: {
                            Image(systemName: "backward.end.fill")
                                .font(.largeTitle)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button { player.togglePlayPause() } label: {
                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 70))
                                .symbolRenderingMode(.hierarchical)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button { player.nextTrack() } label: {
                            Image(systemName: "forward.end.fill")
                                .font(.largeTitle)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button { player.toggleRepeat() } label: {
                            Image(systemName: player.repeatMode.icon)
                                .font(.title3)
                                .foregroundStyle(player.repeatMode != .off ? .green : .white)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .foregroundStyle(.white)
                    
                    // AirPlay / Bottom Row
                    HStack {
                        RoutePickerView()
                            .frame(width: 30, height: 30)
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        // FIX: Pass current song ID for dynamic background
        .background(
            DynamicMusicBackground(albumId: player.currentSong?.coverArt ?? player.currentSong?.albumId)
        )
        .sheet(isPresented: $showingQueue) {
            QueueView()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 { dragOffset = value.translation }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        dismiss()
                    } else {
                        withAnimation { dragOffset = .zero }
                    }
                }
        )
        .offset(y: dragOffset.height)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Stacked Album Art Component
struct StackedAlbumArtView: View {
    let currentSong: Song?
    let queue: [Song]
    let currentIndex: Int
    let screenWidth: CGFloat
    
    var body: some View {
        // FIX: Use max(0, ...) to prevent negative frame crash
        let mainSize = max(0, screenWidth - 60)
        let sideSize = max(0, mainSize * 0.85) // Slightly smaller for side cards
        
        ZStack {
            // Next Song (Right, peeking)
            if currentIndex + 1 < queue.count {
                AlbumImageView(albumId: queue[currentIndex + 1].albumId ?? "", size: 300)
                    .frame(width: sideSize, height: sideSize)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .opacity(0.5)
                    .offset(x: 40) // Peek out right
                    .scaleEffect(0.9)
            }
            
            // Previous Song (Left, peeking)
            if currentIndex > 0 {
                AlbumImageView(albumId: queue[currentIndex - 1].albumId ?? "", size: 300)
                    .frame(width: sideSize, height: sideSize)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .opacity(0.5)
                    .offset(x: -40) // Peek out left
                    .scaleEffect(0.9)
            }
            
            // Current Song (Center)
            if let song = currentSong {
                AlbumImageView(albumId: song.albumId ?? "", size: 600)
                    .frame(width: mainSize, height: mainSize)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 20)
                    .zIndex(1) // Ensure it's on top
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: mainSize, height: mainSize)
                    .overlay(Image(systemName: "music.note").font(.largeTitle))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentIndex)
    }
}

// MARK: - Helper Views
struct RoutePickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.activeTintColor = .white
        view.tintColor = .lightGray
        return view
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
