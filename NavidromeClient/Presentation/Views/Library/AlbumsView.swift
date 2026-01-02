//
//  AlbumsView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Environment(Type.self)
//  - Fixed 'syncLibrary' -> 'refreshAllData'
//

import SwiftUI

struct AlbumsView: View {
    @Environment(MusicLibraryManager.self) var libraryManager
    @Environment(ThemeManager.self) var theme
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: GridColumns.two, spacing: DSLayout.elementGap) {
                        ForEach(libraryManager.albums) { album in
                            NavigationLink(value: album) {
                                CardItemContainer(content: .album(album), index: 0)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(DSLayout.screenPadding)
                    .padding(.bottom, DSLayout.miniPlayerHeight)
                }
            }
            .navigationTitle("Albums")
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
            .task {
                await libraryManager.loadInitialDataIfNeeded()
            }
            .refreshable {
                // Fixed: Use the new method name
                await libraryManager.refreshAllData()
            }
        }
    }
}
