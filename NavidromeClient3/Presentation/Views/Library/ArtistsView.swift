//
//  ArtistsView.swift
//  NavidromeClient3
//
//  Swift 6: Full Implementation with sub-views
//

import SwiftUI
import Observation

struct ArtistsView: View {
    @Environment(MusicLibraryManager.self) private var library
    @Environment(NetworkMonitor.self) private var networkMonitor
    
    var body: some View {
        NavigationStack {
            Group {
                if library.artistLoadingState.isLoading && library.loadedArtists.isEmpty {
                    ProgressView("Loading Artists...")
                } else if case .error(let message) = library.artistLoadingState {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(message))
                } else if library.loadedArtists.isEmpty {
                    ContentUnavailableView("No Artists", systemImage: "music.mic", description: Text("Your library seems empty."))
                } else {
                    List {
                        ForEach(library.loadedArtists) { artist in
                            NavigationLink(destination: ArtistDetailView(artist: artist)) {
                                ArtistRow(artist: artist)
                            }
                            .onAppear {
                                // Pagination
                                if artist.id == library.loadedArtists.last?.id {
                                    Task { await library.loadArtistsProgressively() }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Artists")
            .task {
                if library.loadedArtists.isEmpty && networkMonitor.shouldLoadOnlineContent {
                    await library.loadArtistsProgressively(reset: true)
                }
            }
            .refreshable {
                await library.loadArtistsProgressively(reset: true)
            }
        }
    }
}

// MARK: - Subcomponents

struct ArtistRow: View {
    let artist: Artist
    
    var body: some View {
        HStack(spacing: 12) {
            // FIX: Replaced Placeholder Circle with ArtistImageView
            ArtistImageView(artist: artist, context: .list)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(artist.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                if let count = artist.albumCount {
                    Text("\(count) albums")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ArtistDetailView: View {
    let artist: Artist
    @Environment(MusicLibraryManager.self) private var library
    @State private var albums: [Album] = []
    @State private var isLoading = true
    
    var body: some View {
        List(albums) { album in
            NavigationLink(destination: AlbumDetailView(album: album)) {
                HStack(spacing: 12) {
                    AlbumImageView(album: album, context: .list)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    VStack(alignment: .leading) {
                        Text(album.name)
                            .font(.body)
                        Text(String(album.year ?? 0))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(artist.name)
        .overlay {
            if isLoading {
                ProgressView()
            } else if albums.isEmpty {
                ContentUnavailableView("No Albums", systemImage: "music.note.list")
            }
        }
        .task {
            isLoading = true
            if let fetched = try? await library.loadAlbums(for: artist) {
                self.albums = fetched
            }
            isLoading = false
        }
    }
}
