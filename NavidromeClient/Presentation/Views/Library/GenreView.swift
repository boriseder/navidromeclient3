//
//  GenreView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Environment(Type.self)
//

import SwiftUI

struct GenreView: View {
    @Environment(MusicLibraryManager.self) var libraryManager
    @Environment(ThemeManager.self) var theme
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                List {
                    ForEach(libraryManager.genres, id: \.value) { genre in
                        NavigationLink(value: genre) {
                            Text(genre.value.capitalized)
                                .font(DSText.body)
                                .foregroundStyle(DSColor.onLight)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .padding(.bottom, DSLayout.miniPlayerHeight)
            }
            .navigationTitle("Genres")
            .navigationDestination(for: Genre.self) { genre in
                AlbumCollectionView(context: .byGenre(genre))
            }
            .task {
                await libraryManager.loadInitialDataIfNeeded()
            }
        }
    }
}
