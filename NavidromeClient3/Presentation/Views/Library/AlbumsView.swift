//
//  AlbumsView.swift
//  NavidromeClient3
//
//  Swift 6: Clean List Consumption
//

import SwiftUI

struct AlbumsView: View {
    // 1. Inject Manager
    @Environment(MusicLibraryManager.self) private var library
    
    var body: some View {
        Group {
            if library.isLoading && library.albums.isEmpty {
                ProgressView("Loading Albums...")
            } else if library.albums.isEmpty {
                ContentUnavailableView(
                    "No Albums",
                    systemImage: "music.square.stack",
                    description: Text("Try pulling to refresh")
                )
            } else {
                List {
                    // 2. Direct Property Access (Observation tracks this)
                    ForEach(library.albums) { album in
                        NavigationLink(value: album) {
                            AlbumRow(album: album)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Albums")
        .navigationDestination(for: Album.self) { album in
            AlbumDetailView(album: album)
        }
        .refreshable {
            // 3. Async/Await Support
            await library.refreshAllData()
        }
    }
}
