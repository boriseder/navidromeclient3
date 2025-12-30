//
//  AlbumsView.swift
//  NavidromeClient3
//
//  Swift 6: Full Implementation with Grid & Pagination
//

import SwiftUI

struct AlbumsView: View {
    @Environment(MusicLibraryManager.self) private var library
    @Environment(NetworkMonitor.self) private var networkMonitor
    
    @State private var sortType: AlbumSortType = .alphabetical
    
    // Grid Configuration
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(library.loadedAlbums) { album in
                    NavigationLink(value: album) {
                        CardItemContainer(
                            title: album.name,
                            subtitle: album.artist,
                            imageContext: .card
                        ) {
                            AlbumImageView(album: album, context: .card)
                        }
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        // Pagination: Load more when reaching the end
                        if album.id == library.loadedAlbums.last?.id {
                            Task {
                                await library.loadAlbumsProgressively(sortBy: sortType)
                            }
                        }
                    }
                }
            }
            .padding()
            
            // Loading Indicator at bottom
            if library.albumLoadingState.isLoading {
                ProgressView()
                    .padding()
                    .frame(maxWidth: .infinity)
            } else if library.loadedAlbums.isEmpty && !library.albumLoadingState.isLoading {
                ContentUnavailableView(
                    "No Albums",
                    systemImage: "music.note.list",
                    description: Text("Try refreshing or checking your connection.")
                )
                .padding(.top, 50)
            }
        }
        .navigationTitle("Albums")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sortType) {
                        ForEach(AlbumSortType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
        }
        // FIX: Trigger initial load when view appears
        .task {
            if library.loadedAlbums.isEmpty && networkMonitor.shouldLoadOnlineContent {
                await library.loadAlbumsProgressively(sortBy: sortType, reset: true)
            }
        }
        // Handle Sort Changes
        .onChange(of: sortType) { _, newSort in
            Task {
                await library.loadAlbumsProgressively(sortBy: newSort, reset: true)
            }
        }
        // Pull to Refresh
        .refreshable {
            await library.loadAlbumsProgressively(sortBy: sortType, reset: true)
        }
    }
}
