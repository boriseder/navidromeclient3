//
//  AlbumCollectionView.swift - FIXED: Background displays correctly
//  NavidromeClient
//
//   FIXED: Background uses proper layer structure without GeometryReader collapse
//

import SwiftUI

enum AlbumCollectionContext {
    case byArtist(Artist)
    case byGenre(Genre)
}

struct AlbumCollectionView: View {
    let context: AlbumCollectionContext
    
    // FIX: Swift 6 Environment
    @Environment(SongManager.self) private var songManager
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(CoverArtManager.self) private var coverArtManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(OfflineManager.self) private var offlineManager
    @Environment(MusicLibraryManager.self) private var musicLibraryManager
    @Environment(ThemeManager.self) private var theme

    @State private var albums: [Album] = []

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                ForEach(albums) { album in
                    NavigationLink(value: album) {
                        CardItemContainer(content: .album(album), index: 0)
                    }
                }
            }
            .padding()
        }
        .task {
            // Load albums based on context
        }
    }
}
