//
//  AlbumDetailView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Environment(Type.self)
//  - Refactored wrapper pattern
//

import SwiftUI

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
    @Environment(CoverArtManager.self) var coverArtManager
    @Environment(ThemeManager.self) var theme
    @Environment(NetworkMonitor.self) var networkMonitor
    @Environment(OfflineManager.self) var offlineManager
    @Environment(DownloadManager.self) var downloadManager
    
    @State private var songs: [Song] = []
    
    // Determine if we should show offline version
    private var isOfflineView: Bool {
        if networkMonitor.shouldLoadOnlineContent { return false }
        return downloadManager.isAlbumDownloaded(album.id)
    }
    
    var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    AlbumHeaderView(
                        album: album,
                        songs: songs,
                        isOfflineAlbum: isOfflineView
                    )
                    
                    if songManager.isLoading && songs.isEmpty {
                        ProgressView()
                            .padding(.top, 40)
                    } else if let error = songManager.error, songs.isEmpty {
                        Text("Error: \(error)")
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    } else {
                        AlbumSongsListView(songs: songs, albumId: album.id)
                            .padding(.top, DSLayout.contentPadding)
                    }
                }
                .padding(.horizontal, DSLayout.screenPadding)
                .padding(.bottom, DSLayout.miniPlayerHeight)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if isOfflineView {
                songs = downloadManager.getSongsForPlayback(albumId: album.id)
            } else {
                songs = await songManager.loadSongs(for: album.id)
            }
            
            // Preload full size cover
            if let _ = await coverArtManager.loadAlbumImage(for: album.id, context: .detail) {}
        }
    }
}
