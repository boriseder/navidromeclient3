//
//  ArtistsView.swift
//  NavidromeClient
//
//  Swift 6: @Environment Migration
//

import SwiftUI

struct ArtistsView: View {
    @Environment(MusicLibraryManager.self) private var library
    
    var body: some View {
        Group {
            if library.isLoading && library.artists.isEmpty {
                ProgressView("Loading Artists...")
            } else if library.artists.isEmpty {
                ContentUnavailableView("No Artists", systemImage: "music.mic")
            } else {
                List {
                    ForEach(library.artists) { artist in
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
            // Assuming ArtistDetailView exists, conceptually similar to AlbumDetailView
            Text("Artist Detail: \(artist.name)")
        }
        .refreshable {
            await library.loadArtistsProgressively(reset: true)
        }
    }
}
