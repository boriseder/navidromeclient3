//
//  ArtistsView.swift
//  NavidromeClient
//
//  Fixed: Correct property access 'loadedArtists'
//

import SwiftUI

struct ArtistsView: View {
    @Environment(MusicLibraryManager.self) private var library
    
    var body: some View {
        Group {
            if library.artistLoadingState.isLoading && library.loadedArtists.isEmpty {
                ProgressView("Loading Artists...")
            } else if library.loadedArtists.isEmpty {
                ContentUnavailableView("No Artists", systemImage: "music.mic")
            } else {
                List {
                    // FIX: library.loadedArtists, NOT library.artists
                    ForEach(library.loadedArtists) { artist in
                        NavigationLink(value: artist) {
                            HStack(spacing: DSLayout.elementGap) {
                                ArtistImageView(artist: artist, size: 40)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading) {
                                    Text(artist.name)
                                        .font(DSText.body)
                                        .foregroundColor(DSColor.primary)
                                    
                                    if let count = artist.albumCount {
                                        Text("\(count) albums")
                                            .font(DSText.metadata)
                                            .foregroundColor(DSColor.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Artists")
        .navigationDestination(for: Artist.self) { artist in
            AlbumCollectionView(context: .byArtist(artist))
        }
        .refreshable {
            await library.loadArtistsProgressively(reset: true)
        }
    }
}
