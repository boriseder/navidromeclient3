import SwiftUI
import AVKit

struct FullScreenPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var audioSessionManager: AudioSessionManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var isHorizontalDragging = false
    @State private var showingQueue = false
    @State private var fullscreenImage: UIImage?
    @State private var previousImage: UIImage?
    @State private var nextImage: UIImage?
    @State private var isLoadingFullscreen = false
    @State private var animatingTrackChange = false
    
    private enum TrackDirection {
        case previous, next
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 5) {
                    TopBar(dismiss: dismiss, showingQueue: $showingQueue)
                        .padding(.horizontal, 20)
                    Spacer(minLength: 30)
                    
                    SpotifyStackedAlbumArt(
                        currentCover: fullscreenImage,
                        previousCover: previousImage,
                        nextCover: nextImage,
                        horizontalDragOffset: horizontalDragOffset,
                        isHorizontalDragging: isHorizontalDragging,
                        isLoadingFullscreen: isLoadingFullscreen,
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
                .environmentObject(playerVM)
                .environmentObject(coverArtManager)
        }
        .onAppear {
            Task {
                await loadFullscreenImage()
                await preloadAdjacentCovers()
            }
        }
        .task(id: "\(playerVM.currentSong?.albumId ?? "")_\(coverArtManager.cacheGeneration)") {
            await loadFullscreenImage()
            await preloadAdjacentCovers()
        }
    }
    
    private func loadFullscreenImage() async {
        guard let albumId = playerVM.currentSong?.albumId else {
            await MainActor.run {
                fullscreenImage = nil
                isLoadingFullscreen = false
            }
            return
        }
        
        if let cached = coverArtManager.getAlbumImage(for: albumId, context: .fullscreen) {
            await MainActor.run {
                fullscreenImage = cached
                isLoadingFullscreen = false
            }
            await preloadAdjacentCovers()
            return
        }
        
        await MainActor.run { isLoadingFullscreen = true }
        
        let image = await coverArtManager.loadAlbumImage(for: albumId, context: .fullscreen)
        
        await MainActor.run {
            fullscreenImage = image
            isLoadingFullscreen = false
        }
        
        await preloadAdjacentCovers()
    }
    
    private func preloadAdjacentCovers() async {
        let playlist = playerVM.currentPlaylist
        let currentIdx = playerVM.currentIndex
        
        guard !playlist.isEmpty else { return }
        
        async let previous = loadPreviousCover(playlist: playlist, currentIndex: currentIdx)
        async let next = loadNextCover(playlist: playlist, currentIndex: currentIdx)
        
        let (prevImg, nextImg) = await (previous, next)
        
        await MainActor.run {
            previousImage = prevImg
            nextImage = nextImg
        }
    }
    
    private func loadPreviousCover(playlist: [Song], currentIndex: Int) async -> UIImage? {
        guard currentIndex > 0 else {
            if playerVM.repeatMode == .all && !playlist.isEmpty {
                return await loadCoverForSong(playlist[playlist.count - 1])
            }
            return nil
        }
        return await loadCoverForSong(playlist[currentIndex - 1])
    }
    
    private func loadNextCover(playlist: [Song], currentIndex: Int) async -> UIImage? {
        guard currentIndex + 1 < playlist.count else {
            if playerVM.repeatMode == .all && !playlist.isEmpty {
                return await loadCoverForSong(playlist[0])
            }
            return nil
        }
        return await loadCoverForSong(playlist[currentIndex + 1])
    }
    
    private func loadCoverForSong(_ song: Song) async -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        
        if let cached = coverArtManager.getAlbumImage(for: albumId, context: .fullscreen) {
            return cached
        }
        return await coverArtManager.loadAlbumImage(for: albumId, context: .fullscreen)
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
        
        if translation > threshold && previousImage != nil {
            animatingTrackChange = true
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                horizontalDragOffset = snapDistance
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Task {
                    await MainActor.run {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            horizontalDragOffset = 0
                            
                            let oldPrevious = previousImage
                            let oldCurrent = fullscreenImage
                            
                            fullscreenImage = oldPrevious
                            nextImage = oldCurrent
                        }
                    }
                    
                    await playerVM.playPrevious()
                    
                    await MainActor.run {
                        animatingTrackChange = false
                    }
                    
                    let playlist = playerVM.currentPlaylist
                    let currentIdx = playerVM.currentIndex
                    if currentIdx > 0 {
                        let newPrevImage = await loadCoverForSong(playlist[currentIdx - 1])
                        await MainActor.run {
                            previousImage = newPrevImage
                        }
                    } else if playerVM.repeatMode == .all && !playlist.isEmpty {
                        let newPrevImage = await loadCoverForSong(playlist[playlist.count - 1])
                        await MainActor.run {
                            previousImage = newPrevImage
                        }
                    } else {
                        await MainActor.run {
                            previousImage = nil
                        }
                    }
                }
            }
            
        } else if translation < -threshold && nextImage != nil {
            animatingTrackChange = true
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                horizontalDragOffset = -snapDistance
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Task {
                    await MainActor.run {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            horizontalDragOffset = 0
                            
                            let oldCurrent = fullscreenImage
                            let oldNext = nextImage
                            
                            fullscreenImage = oldNext
                            previousImage = oldCurrent
                        }
                    }
                    
                    await playerVM.playNext()
                    
                    await MainActor.run {
                        animatingTrackChange = false
                    }
                    
                    let playlist = playerVM.currentPlaylist
                    let currentIdx = playerVM.currentIndex
                    if currentIdx + 1 < playlist.count {
                        let newNextImage = await loadCoverForSong(playlist[currentIdx + 1])
                        await MainActor.run {
                            nextImage = newNextImage
                        }
                    } else if playerVM.repeatMode == .all && !playlist.isEmpty {
                        let newNextImage = await loadCoverForSong(playlist[0])
                        await MainActor.run {
                            nextImage = newNextImage
                        }
                    } else {
                        await MainActor.run {
                            nextImage = nil
                        }
                    }
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

// MARK: - Stacked Album Art
struct SpotifyStackedAlbumArt: View {
    let currentCover: UIImage?
    let previousCover: UIImage?
    let nextCover: UIImage?
    let horizontalDragOffset: CGFloat
    let isHorizontalDragging: Bool
    let isLoadingFullscreen: Bool
    let screenWidth: CGFloat
    
    var body: some View {
        ZStack {
            if let previous = previousCover {
                AlbumCoverCard(cover: previous, screenWidth: screenWidth)
                    .offset(x: calculateOffset(for: .previous))
                    .zIndex(5)
            }
            
            AlbumCoverCard(cover: currentCover, screenWidth: screenWidth, isLoading: isLoadingFullscreen)
                .offset(x: calculateOffset(for: .current))
                .zIndex(10)
            
            if let next = nextCover {
                AlbumCoverCard(cover: next, screenWidth: screenWidth)
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
    
    private func calculateZIndex(for position: CardPosition) -> Double {
        guard isHorizontalDragging else { return position == .current ? 10 : 5 }
        switch position {
        case .previous: return horizontalDragOffset > 0 ? 15 : 5
        case .current: return 10
        case .next: return horizontalDragOffset < 0 ? 15 : 5
        }
    }
}

// MARK: - Album Cover Card
struct AlbumCoverCard: View {
    let cover: UIImage?
    let screenWidth: CGFloat
    var isLoading: Bool = false
    
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
    }
}

// MARK: - Background
struct SpotifyBackground: View {
    let image: UIImage?
    
    var body: some View {
        ZStack {
            if let cover = image {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 20)
                    .opacity(0.9)
                    .scaleEffect(1.4)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - TopBar
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

// MARK: - Song Info
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

// MARK: - Progress Section
struct ProgressSection: View {
    @ObservedObject var playerVM: PlayerViewModel
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

// MARK: - Main Controls
struct MainControls: View {
    @ObservedObject var playerVM: PlayerViewModel
    
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

// MARK: - Bottom Controls
struct BottomControls: View {
    @ObservedObject var playerVM: PlayerViewModel
    let audioSessionManager: AudioSessionManager
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

// MARK: - Audio Source Button
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
