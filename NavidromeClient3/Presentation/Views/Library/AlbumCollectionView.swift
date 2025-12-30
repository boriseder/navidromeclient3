//
//  AlbumCollectionView.swift
//  NavidromeClient
//
//  Fixed: Removed conflicting navigationDestination
//

import SwiftUI

enum AlbumCollectionContext {
    case byArtist(Artist)
    case byGenre(Genre)
}

struct AlbumCollectionView: View {
    let context: AlbumCollectionContext
    
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(OfflineManager.self) private var offlineManager
    @Environment(MusicLibraryManager.self) private var musicLibraryManager
    @Environment(ThemeManager.self) private var theme

    @State private var albums: [NavidromeClient3.Album] = []

    private var displayedAlbums: [NavidromeClient3.Album] {
        return networkMonitor.shouldLoadOnlineContent ? albums : availableOfflineAlbums
    }
    
    private var availableOfflineAlbums: [NavidromeClient3.Album] {
        switch context {
        case .byArtist(let artist):
            return offlineManager.getOfflineAlbums(for: artist)
        case .byGenre(let genre):
            return offlineManager.getOfflineAlbums(for: genre)
        }
    }
    
    var body: some View {
        ZStack {
            theme.backgroundColor.opacity(0.3)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    contentView
                        .padding(.top, DSLayout.contentPadding)
                }
                .padding(.horizontal, DSLayout.screenPadding)
                .padding(.bottom, DSLayout.miniPlayerHeight)
                .padding(.top, -40)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            // FIX: Removed .navigationDestination to prevent conflicts with ContentView
            .scrollIndicators(.hidden)
            .task {
                await loadContent()
            }
            .refreshable {
                guard networkMonitor.shouldLoadOnlineContent else { return }
                await loadContent()
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        LazyVGrid(columns: GridColumns.two, alignment: .leading, spacing: DSLayout.elementGap) {
            ForEach(Array(displayedAlbums.enumerated()), id: \.element.id) { index, album in
                NavigationLink(value: album) {
                    CardItemContainer(
                        title: album.name,
                        subtitle: album.artist,
                        imageContext: .card
                    ) {
                        AlbumImageView(album: album, context: .card)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @MainActor
    private func loadContent() async {
        do {
            switch context {
            case .byArtist(let artist):
                if let loaded = try? await musicLibraryManager.loadAlbums(for: artist) {
                    self.albums = loaded
                }
            case .byGenre(let genre):
                if let loaded = try? await musicLibraryManager.loadAlbums(for: genre) {
                    self.albums = loaded
                }
            }
        }
    }
}
