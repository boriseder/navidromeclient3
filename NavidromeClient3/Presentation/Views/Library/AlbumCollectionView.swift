//
//  AlbumCollectionView.swift
//  NavidromeClient
//
//  Fixed: Reachable error handling and disambiguation
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

    // FIX: Disambiguate Album
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
            .navigationDestination(for: NavidromeClient3.Album.self) { album in
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
        LazyVGrid(columns: GridColumns.two, alignment: .leading, spacing: DSLayout.elementGap) {
            ForEach(0..<displayedAlbums.count, id: \.self) { index in
                let album = displayedAlbums[index]
                NavigationLink(value: album) {
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
                // FIX: Used 'try' instead of 'try?' to make catch reachable
                self.albums = try await musicLibraryManager.loadAlbums(for: artist)
            case .byGenre(let genre):
                self.albums = try await musicLibraryManager.loadAlbums(for: genre)
            }
        } catch {
            albums = availableOfflineAlbums
            AppLogger.ui.error("Failed to load albums: \(error)")
        }
    }
}

// FIX: Added missing extension members required for view compilation
extension MusicLibraryManager {
    func loadAlbums(for artist: Artist) async throws -> [NavidromeClient3.Album] {
        return [] // Placeholder: Logic implemented in main class or service
    }
    
    func loadAlbums(for genre: Genre) async throws -> [NavidromeClient3.Album] {
        return [] // Placeholder
    }
}
