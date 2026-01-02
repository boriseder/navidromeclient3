//
//  ArtistsView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Environment(Type.self)
//

import SwiftUI

struct ArtistsView: View {
    @Environment(MusicLibraryManager.self) var libraryManager
    @Environment(ThemeManager.self) var theme
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                List {
                    ForEach(libraryManager.artists) { artist in
                        NavigationLink(value: artist) {
                            HStack {
                                ArtistImageView(artist: artist, context: .artistList)
                                    .frame(width: 40, height: 40)
                                Text(artist.name)
                                    .font(DSText.body)
                                    .foregroundStyle(DSColor.onLight)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .padding(.bottom, DSLayout.miniPlayerHeight)
            }
            .navigationTitle("Artists")
            .navigationDestination(for: Artist.self) { artist in
                AlbumCollectionView(context: .byArtist(artist))
            }
            .task {
                await libraryManager.loadInitialDataIfNeeded()
            }
        }
    }
}
