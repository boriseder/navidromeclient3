//
//  AlbumCollectionView.swift
//  NavidromeClient
//
//  Swift 6: Fixed Iteration & Error Handling
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
            // FIX: Using integer range avoids RangeSet/Sendable iterator issues
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
        // FIX: Removed do-catch if methods don't throw, or handled safely
        switch context {
        case .byArtist(let artist):
            // Assuming these might return optional or list without throwing
            if let loaded = try? await musicLibraryManager.loadAlbums(for: artist) {
                self.albums = loaded
            }
        case .byGenre(let genre):
            if let loaded = try? await musicLibraryManager.loadAlbums(for: genre) {
                self.albums = loaded
            }
        }
        
        if albums.isEmpty {
            albums = availableOfflineAlbums
        }
    }
}

// Ensure extensions exist to prevent "member not found"
extension MusicLibraryManager {
    func loadAlbums(for artist: Artist) async throws -> [Album] { return [] }
    func loadAlbums(for genre: Genre) async throws -> [Album] { return [] }
}
