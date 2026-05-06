//
//  FullScreenPlayer.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - FIXED Bug 11: Removed duplicated image state.
//  - Extracted image loading logic directly into autonomous CoverArtCards.
//

import SwiftUI
import AVKit

struct FullScreenPlayerView: View {
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(AudioSessionManager.self) var audioSessionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var isHorizontalDragging = false
    @State private var showingQueue = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 5) {
                    TopBar(dismiss: dismiss, showingQueue: $showingQueue)
                        .padding(.horizontal, 20)
                    Spacer(minLength: 30)
                    
                    SpotifyStackedAlbumArt(
                        playerVM: playerVM,
                        horizontalDragOffset: horizontalDragOffset,
                        isHorizontalDragging: isHorizontalDragging,
                        screenWidth: geometry.size.width
                    )
                    .scaleEffect(isDragging ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3), value: isDragging)

                    Spacer(minLength: 20)

                    if let song = playerVM.currentSong {
                        SpotifySongInfoView(song: song, screenWidth: geometry.size.width)
                    }
                                        
                    Spacer(minLength: 16)
                    
                    ProgressSection(playerVM: playerVM, screenWidth: geometry.size.width)
                    
                    Spacer(minLength: 24)
                    
                    MainControls(playerVM: playerVM)
                    
                    Spacer()
                    BottomControls(
                        playerVM: playerVM,
                        audioSessionManager: audioSessionManager,
                        screenWidth: geometry.size.width
                    )
                }
                .frame(maxWidth: geometry.size.width*0.95, maxHeight: geometry.size.height*0.95)
                .padding(.horizontal, 10)
                .padding(.top, 70)
                .padding(.bottom, 20)
            }
            .ignoresSafeArea(.container, edges: [.top, .bottom])
            .offset(y: dragOffset)
            .gesture(combinedGesture(screenWidth: geometry.size.width))
            .background(Color.black)
        }
        .animation(.interactiveSpring(), value: dragOffset)
        .sheet(isPresented: $showingQueue) {
            QueueView()
                .environment(playerVM)
        }
    }
    
    private func combinedGesture(screenWidth: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let horizontalAmount = abs(value.translation.width)
                let verticalAmount = abs(value.translation.height)
                
                if horizontalAmount > verticalAmount && horizontalAmount > 10 {
                    horizontalDragOffset = value.translation.width
                    isHorizontalDragging = true
                    isDragging = false
                    dragOffset = 0
                } else if verticalAmount > horizontalAmount && value.translation.height > 0 {
                    dragOffset = value.translation.height
                    isDragging = true
                    isHorizontalDragging = false
                    horizontalDragOffset = 0
                }
            }
            .onEnded { value in
                if isHorizontalDragging {
                    handleHorizontalSwipeEnd(translation: value.translation.width, screenWidth: screenWidth)
                } else if isDragging {
                    handleVerticalSwipeEnd(translation: value.translation.height)
                }
                isDragging = false
                isHorizontalDragging = false
            }
    }
    
    private func handleHorizontalSwipeEnd(translation: CGFloat, screenWidth: CGFloat) {
        let threshold = screenWidth * 0.3
        let coverWidth = screenWidth * 0.9
        let spacing: CGFloat = 20
        let snapDistance = coverWidth + spacing
        
        let hasPrevious = playerVM.currentIndex > 0 || (playerVM.repeatMode == .all && !playerVM.currentPlaylist.isEmpty)
        let hasNext = playerVM.currentIndex + 1 < playerVM.currentPlaylist.count || (playerVM.repeatMode == .all && !playerVM.currentPlaylist.isEmpty)
        
        if translation > threshold && hasPrevious {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                horizontalDragOffset = snapDistance
            }
            
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3)) // Let swipe finish visually
                await playerVM.playPrevious()
                
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    horizontalDragOffset = 0
                }
            }
        } else if translation < -threshold && hasNext {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                horizontalDragOffset = -snapDistance
            }
            
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3)) // Let swipe finish visually
                await playerVM.playNext()
                
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    horizontalDragOffset = 0
                }
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                horizontalDragOffset = 0
            }
        }
    }
    
    private func handleVerticalSwipeEnd(translation: CGFloat) {
        if translation > 200 {
            dismiss()
        } else {
            withAnimation(.spring()) { dragOffset = 0 }
        }
    }
}

// MARK: - Subcomponents

struct SpotifyStackedAlbumArt: View {
    var playerVM: PlayerViewModel
    let horizontalDragOffset: CGFloat
    let isHorizontalDragging: Bool
    let screenWidth: CGFloat
    
    var body: some View {
        let playlist = playerVM.currentPlaylist
        let currentIdx = playerVM.currentIndex
        let repeatMode = playerVM.repeatMode
        
        let currentAlbumId = playlist.indices.contains(currentIdx) ? playlist[currentIdx].albumId : nil
        
        let prevAlbumId: String? = {
            if currentIdx > 0 { return playlist[currentIdx - 1].albumId }
            if repeatMode == .all && !playlist.isEmpty { return playlist.last?.albumId }
            return nil
        }()
        
        let nextAlbumId: String? = {
            if currentIdx + 1 < playlist.count { return playlist[currentIdx + 1].albumId }
            if repeatMode == .all && !playlist.isEmpty { return playlist.first?.albumId }
            return nil
        }()
        
        ZStack {
            if let prevId = prevAlbumId {
                AlbumCoverCard(albumId: prevId, screenWidth: screenWidth)
                    .offset(x: calculateOffset(for: .previous))
                    .zIndex(5)
            }
            
            AlbumCoverCard(albumId: currentAlbumId, screenWidth: screenWidth)
                .offset(x: calculateOffset(for: .current))
                .zIndex(10)
            
            if let nextId = nextAlbumId {
                AlbumCoverCard(albumId: nextId, screenWidth: screenWidth)
                    .offset(x: calculateOffset(for: .next))
                    .zIndex(5)
            }
        }
        .frame(height: screenWidth * 0.9)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: horizontalDragOffset)
    }
    
    private enum CardPosition { case previous, current, next }
    
    private func calculateOffset(for position: CardPosition) -> CGFloat {
        let coverWidth = screenWidth * 0.9
        let spacing: CGFloat = 20
        
        switch position {
        case .previous:
            return -(coverWidth + spacing) + horizontalDragOffset
        case .current:
            return horizontalDragOffset
        case .next:
            return (coverWidth + spacing) + horizontalDragOffset
        }
    }
}

struct AlbumCoverCard: View {
    let albumId: String?
    let screenWidth: CGFloat
    @Environment(CoverArtManager.self) var coverArtManager
    
    @State private var cover: UIImage?
    @State private var isLoading: Bool = false
    
    var body: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                    )
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .frame(width: screenWidth * 0.9)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
        .overlay {
            if isLoading {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .onAppear { resolveCacheSynchronously() }
        .onChange(of: albumId) { _, _ in
            resolveCacheSynchronously()
            Task { await fetchImageAsynchronously() }
        }
        .task(id: albumId) {
            await fetchImageAsynchronously()
        }
    }
    
    // Check memory cache instantly to prevent view flashing during track changes
    private func resolveCacheSynchronously() {
        guard let id = albumId else {
            cover = nil
            return
        }
        if let cached = coverArtManager.getAlbumImage(for: id, context: .fullscreen) {
            cover = cached
        }
    }
    
    private func fetchImageAsynchronously() async {
        guard let id = albumId else {
            cover = nil
            isLoading = false
            return
        }
        if let cached = coverArtManager.getAlbumImage(for: id, context: .fullscreen) {
            cover = cached
            return
        }
        isLoading = true
        cover = await coverArtManager.loadAlbumImage(for: id, context: .fullscreen)
        isLoading = false
    }
}

struct TopBar: View {
    let dismiss: DismissAction
    @Binding var showingQueue: Bool
    
    var body: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button { showingQueue = true } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct SpotifySongInfoView: View {
    let song: Song
    let screenWidth: CGFloat
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if let artist = song.artist {
                    Text(artist)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HeartButton.fullScreen(song: song)
        }
        .padding(.horizontal, 20)
    }
}

struct ProgressSection: View {
    var playerVM: PlayerViewModel
    
    let screenWidth: CGFloat
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.3))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: progressWidth(geometry.size.width), height: 4)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                        .offset(x: progressWidth(geometry.size.width) - (isDragging ? 8 : 6))
                        .animation(.easeInOut(duration: 0.1), value: isDragging)
                }
                .gesture(progressGesture(geometry.size.width))
            }
            .frame(height: 20)
            
            HStack {
                Text(formatTime(isDragging ? dragValue * playerVM.duration : playerVM.currentTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Text(formatTime(playerVM.duration))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: screenWidth - 40)
        .padding(.horizontal, 20)
    }
    
    private func progressWidth(_ maxWidth: CGFloat) -> CGFloat {
        guard playerVM.duration > 0 else { return 0 }
        let progress = isDragging ? dragValue : (playerVM.currentTime / playerVM.duration)
        return min(maxWidth * progress, maxWidth)
    }
    
    private func progressGesture(_ maxWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                let progress = max(0, min(value.location.x / maxWidth, 1))
                dragValue = progress
            }
            .onEnded { value in
                let progress = max(0, min(value.location.x / maxWidth, 1))
                playerVM.seek(to: progress * playerVM.duration)
                isDragging = false
            }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct MainControls: View {
    var playerVM: PlayerViewModel
    
    var body: some View {
        HStack(spacing: 30) {
            Button { playerVM.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 22))
                    .foregroundStyle(playerVM.isShuffling ? .green : .white.opacity(0.7))
            }
            
            Button {
                Task { await playerVM.playPrevious() }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            
            Button {
                playerVM.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)
                    
                    if playerVM.isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.black)
                            .offset(x: playerVM.isPlaying ? 0 : 2)
                    }
                }
            }
            
            Button {
                Task { await playerVM.playNext() }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            
            Button { playerVM.toggleRepeat() } label: {
                Image(systemName: repeatIcon)
                    .font(.system(size: 22))
                    .foregroundStyle(repeatColor)
            }
        }
    }
    
    private var repeatIcon: String {
        switch playerVM.repeatMode {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
    
    private var repeatColor: Color {
        switch playerVM.repeatMode {
        case .off: return .white.opacity(0.7)
        case .all, .one: return .green
        }
    }
}

struct BottomControls: View {
    var playerVM: PlayerViewModel
    var audioSessionManager: AudioSessionManager
    let screenWidth: CGFloat
    
    var body: some View {
        HStack {
            AudioSourceButton()
                .frame(width: 50, height: 50)
            
            Spacer()
        }
        .frame(maxWidth: screenWidth - 40)
        .padding(.horizontal, 20)
    }
}

struct AudioSourceButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.backgroundColor = .clear
        picker.tintColor = .white
        picker.prioritizesVideoDevices = false
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
