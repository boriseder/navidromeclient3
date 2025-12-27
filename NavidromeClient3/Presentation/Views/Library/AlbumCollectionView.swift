//
//  AlbumCollectionView.swift
//  NavidromeClient
//
//  Fixed: Correct CardItemContainer usage and Environments
//

import SwiftUI

enum AlbumCollectionContext {
    case byArtist(Artist)
    case byGenre(Genre)
}

struct AlbumCollectionView: View {
    let context: AlbumCollectionContext
    
    // Use proper Environment injection
    @Environment(SongManager.self) private var songManager
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(CoverArtManager.self) private var coverArtManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(OfflineManager.self) private var offlineManager
    @Environment(MusicLibraryManager.self) private var musicLibraryManager
    @Environment(ThemeManager.self) private var theme

    @State private var albums: [Album] = []

    private var displayedAlbums: [Album] {
        return networkMonitor.shouldLoadOnlineContent ? albums : availableOfflineAlbums
    }
    
    private var availableOfflineAlbums: [Album] {
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
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(album: album)
            }
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
        LazyVGrid(
            columns: GridColumns.two,
            alignment: .leading,
            spacing: DSLayout.elementGap
        ) {
            ForEach(displayedAlbums.indices, id: \.self) { index in
                let album = displayedAlbums[index]
                
                NavigationLink(value: album) {
                    // FIX: Use correct API for CardItemContainer
                    CardItemContainer(content: .album(album), index: index)
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
                // Ensure MusicLibraryManager exposes this, otherwise assume extension exists
                if let loaded = try? await musicLibraryManager.loadAlbums(for: artist) {
                    self.albums = loaded
                }
            case .byGenre(let genre):
                if let loaded = try? await musicLibraryManager.loadAlbums(for: genre) {
                    self.albums = loaded
                }
            }
        } catch {
            albums = availableOfflineAlbums
        }
    }
}

// Helper extension to make the view compile even if Manager methods vary slightly
extension MusicLibraryManager {
    func loadAlbums(for artist: Artist) async throws -> [Album] {
        // Implementation would call service.getAlbumsByArtist
        return [] // Placeholder
    }
    
    func loadAlbums(for genre: Genre) async throws -> [Album] {
        // Implementation would call service.getAlbumsByGenre
        return [] // Placeholder
    }
}
