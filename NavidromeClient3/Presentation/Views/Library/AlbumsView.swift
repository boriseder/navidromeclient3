//
//  AlbumsView.swift
//  NavidromeClient
//
//  Swift 6: @Environment Migration
//

import SwiftUI

struct AlbumsView: View {
    @Environment(MusicLibraryManager.self) private var library
    @Environment(PlayerViewModel.self) private var player
    
    // Local state for sorting/filtering is fine as @State
    @State private var sortType: ContentService.AlbumSortType = .alphabetical
    
    var body: some View {
        Group {
            if library.isLoading && library.albums.isEmpty {
                ProgressView("Loading Albums...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if library.albums.isEmpty {
                ContentUnavailableView(
                    "No Albums Found",
                    systemImage: "music.square.stack",
                    description: Text("Try pulling to refresh or check your connection.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: GridColumns.two, spacing: DSLayout.contentGap) {
                        ForEach(library.albums) { album in
                            NavigationLink(value: album) {
                                CardItemContainer(
                                    title: album.name,
                                    subtitle: album.artist,
                                    imageContext: .card
                                ) {
                                    AlbumImageView(
                                        albumId: album.id,
                                        size: ImageContext.card.size
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(DSLayout.screenPadding)
                }
            }
        }
        .navigationTitle("Albums")
        .navigationDestination(for: Album.self) { album in
            AlbumDetailView(album: album)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sortType) {
                        ForEach(ContentService.AlbumSortType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
        }
        .onChange(of: sortType) { _, newSort in
            Task {
                await library.loadAlbumsProgressively(sortBy: newSort, reset: true)
            }
        }
        .refreshable {
            await library.loadAlbumsProgressively(sortBy: sortType, reset: true)
        }
    }
}
