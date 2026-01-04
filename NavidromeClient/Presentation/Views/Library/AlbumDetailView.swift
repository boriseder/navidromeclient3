//
//  AlbumDetailView.swift - RESTORED: Full Swift 5 Functionality
//  NavidromeClient
//
//  Swift 6 Compliance with ALL original features restored
//

import SwiftUI
import Observation

// Wrapper to handle navigation destination matching
struct AlbumDetailViewContent: View {
    let album: Album
    var body: some View {
        AlbumDetailView(album: album)
    }
}

struct AlbumDetailView: View {
    let album: Album
    
    @Environment(SongManager.self) var songManager
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(DownloadManager.self) var downloadManager
    @Environment(CoverArtManager.self) var coverArtManager
    @Environment(NetworkMonitor.self) var networkMonitor
    @Environment(OfflineManager.self) var offlineManager
    @Environment(ThemeManager.self) var theme

    @State private var songs: [Song] = []
    @State private var isOfflineAlbum = false
    @State private var backgroundImageLoaded = false
    
    var body: some View {
        ZStack {
            // Background Layer
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
                        albumId: album.id
                    )
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
            return
        }
        
        // Load with high priority
        let image = await coverArtManager.loadAlbumImage(
            for: album.id,
            context: .fullscreen
        )
        
        if image != nil {
            backgroundImageLoaded = true
        }
    }
    
    @MainActor
    private func loadAlbumData() async {
        let isNetworkOffline = !networkMonitor.canLoadOnlineContent
        let isDownloaded = downloadManager.isAlbumDownloaded(album.id)
        
        isOfflineAlbum = isNetworkOffline || isDownloaded
        songs = await songManager.loadSongs(for: album.id)
    }
    
    // MARK: - Background View
    
    @ViewBuilder
    private var blurredAlbumBackground: some View {
        Color.clear
            .overlay(
                AlbumImageView(album: album, context: .fullscreen)
                    .frame(
                        width: CGFloat(ImageContext.fullscreen.size),
                        height: CGFloat(ImageContext.fullscreen.size)
                    )
                    .blur(radius: 20)
                    .scaleEffect(1.5)
                    .offset(y: -100)
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
