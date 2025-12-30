import SwiftUI

struct AlbumDetailViewContent: View {
    let album: Album
    
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var theme: ThemeManager

    @State private var songs: [Song] = []
    @State private var isOfflineAlbum = false
    @State private var backgroundImageLoaded = false
    
    var body: some View {
        ZStack {
            if backgroundImageLoaded {
                blurredAlbumBackground.transition(.opacity)
            }
            theme.backgroundColor.opacity(0.3).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 1) {
                     AlbumHeaderView(album: album, songs: songs, isOfflineAlbum: isOfflineAlbum)
                     AlbumSongsListView(songs: songs, album: album)
                }
                .padding(.horizontal, DSLayout.screenPadding)
                .padding(.bottom, DSLayout.miniPlayerHeight)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadBackgroundImage()
                await loadAlbumData()
            }
            .scrollIndicators(.hidden)
            .onReceive(NotificationCenter.default.publisher(for: .downloadCompleted)) { notification in
                if let albumId = notification.object as? String, albumId == album.id {
                    Task { await loadAlbumData() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .downloadDeleted)) { notification in
                if let albumId = notification.object as? String, albumId == album.id {
                    Task { await loadAlbumData() }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: backgroundImageLoaded)
    }
    
    @MainActor
    private func loadBackgroundImage() async {
        if coverArtManager.getAlbumImage(for: album.id, context: .fullscreen) != nil {
            backgroundImageLoaded = true
            return
        }
        let image = await coverArtManager.loadAlbumImage(for: album.id, context: .fullscreen)
        if image != nil { backgroundImageLoaded = true }
    }
    
    @MainActor
    private func loadAlbumData() async {
        let isNetworkOffline = !networkMonitor.shouldLoadOnlineContent
        let isDownloaded = downloadManager.isAlbumDownloaded(album.id)
        isOfflineAlbum = isNetworkOffline || isDownloaded
        songs = await songManager.loadSongs(for: album.id)
    }
    
    @ViewBuilder
    private var blurredAlbumBackground: some View {
        Color.clear
            .overlay(
                AlbumImageView(album: album, context: .fullscreen)
                    .frame(width: CGFloat(ImageContext.fullscreen.size), height: CGFloat(ImageContext.fullscreen.size))
                    .blur(radius: 20)
                    .scaleEffect(1.5)
                    .offset(y: -100)
            )
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(0.7), .black.opacity(0.35), .black.opacity(0.3), .black.opacity(0.2), .black.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .ignoresSafeArea()
    }
}
