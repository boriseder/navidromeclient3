//
//  AlbumDetailView.swift - FIXED: Background displays correctly
//  NavidromeClient
//
//  FIXED: Background uses proper layer structure
//  FIXED: Fullscreen image loading tracked with @State
//

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
    @State private var backgroundImageLoaded = false // 🆕 Track background loading
    
    var body: some View {
        ZStack {
            // Background Layer - FIXED
            if backgroundImageLoaded {
                blurredAlbumBackground
                    .transition(.opacity)
            }
            
            theme.backgroundColor.opacity(0.3)
                .ignoresSafeArea()

            // Content Layer
            ScrollView {
                VStack(spacing: 1) {
                     AlbumHeaderView(
                        album: album,
                        songs: songs,
                        isOfflineAlbum: isOfflineAlbum
                     )
                     
                     AlbumSongsListView(
                        songs: songs,
                        album: album
                     )
                }
                .padding(.horizontal, DSLayout.screenPadding)
                .padding(.bottom, DSLayout.miniPlayerHeight)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // 🆕 Load background image FIRST
                await loadBackgroundImage()
                
                // Then load content
                await loadAlbumData()
            }
            .scrollIndicators(.hidden)
            .onReceive(NotificationCenter.default.publisher(for: .downloadCompleted)) { notification in
                if let albumId = notification.object as? String, albumId == album.id {
                    Task {
                        await loadAlbumData()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .downloadDeleted)) { notification in
                if let albumId = notification.object as? String, albumId == album.id {
                    Task {
                        await loadAlbumData()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: backgroundImageLoaded)
    }
    
    // MARK: - Background Loading
    
    @MainActor
    private func loadBackgroundImage() async {
        // Check if already loaded
        if coverArtManager.getAlbumImage(for: album.id, context: .fullscreen) != nil {
            backgroundImageLoaded = true
            AppLogger.ui.info("✅ Album background image already cached: \(album.name)")
            return
        }
        
        // Load with high priority
        let image = await coverArtManager.loadAlbumImage(
            for: album.id,
            context: .fullscreen
        )
        
        if image != nil {
            backgroundImageLoaded = true
            AppLogger.ui.info("✅ Album background image loaded: \(album.name)")
        } else {
            AppLogger.ui.warn("❌ Failed to load album background image: \(album.name)")
        }
    }
    
    @MainActor
    private func loadAlbumData() async {
        let isNetworkOffline = !networkMonitor.shouldLoadOnlineContent
        let isDownloaded = downloadManager.isAlbumDownloaded(album.id)
        
        isOfflineAlbum = isNetworkOffline || isDownloaded
        
        songs = await songManager.loadSongs(for: album.id)
    }
    
    // MARK: - Background View - FIXED
    
    @ViewBuilder
    private var blurredAlbumBackground: some View {
        // Use Color as base layer to ensure proper sizing
        Color.clear
            .overlay(
                AlbumImageView(album: album, context: .fullscreen)
                    .frame(
                        width: CGFloat(ImageContext.fullscreen.size),
                        height: CGFloat(ImageContext.fullscreen.size)
                    )
                    .blur(radius: 20)
                    .scaleEffect(1.5) // Scale up to cover edges after blur
                    .offset(y: -100) // Shift up to center on top portion
            )
            .overlay(
                LinearGradient(
                    colors: [
                        .black.opacity(0.7),
                        .black.opacity(0.35),
                        .black.opacity(0.3),
                        .black.opacity(0.2),
                        .black.opacity(0.7),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .ignoresSafeArea()
    }
}
