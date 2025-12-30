//
//  GenreView.swift
//  NavidromeClient3
//
//  Swift 6: Full Implementation with sub-views
//

import SwiftUI

struct GenreView: View {
    @Environment(MusicLibraryManager.self) private var musicLibraryManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @State private var debouncer = Debouncer(delay: 0.5)
    
    var body: some View {
        List {
            ForEach(musicLibraryManager.loadedGenres) { genre in
                NavigationLink(destination: GenreDetailView(genre: genre)) {
                    GenreRowView(genre: genre)
                }
            }
        }
        .searchable(text: $debouncer.input)
        .navigationTitle("Genres")
        .task {
            if musicLibraryManager.loadedGenres.isEmpty {
                await musicLibraryManager.loadGenresProgressively()
            }
        }
        .refreshable {
            await musicLibraryManager.loadGenresProgressively(reset: true)
        }
    }
}

// MARK: - Subcomponents

struct GenreRowView: View {
    let genre: Genre
    // We removed 'index' and 'ThemeManager' environment usage to simplify and fix missing dependencies
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "music.note.list")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(genre.value)
                .font(.body)
                .lineLimit(1)
            
            Spacer()
            
            Text("\(genre.albumCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

struct GenreDetailView: View {
    let genre: Genre
    @Environment(MusicLibraryManager.self) private var library
    @State private var albums: [Album] = []
    @State private var isLoading = true
    
    var body: some View {
        List(albums) { album in
            NavigationLink(destination: AlbumDetailView(album: album)) {
                HStack(spacing: 12) {
                    // FIX: Removed 'size' argument. Using .frame instead.
                    AlbumImageView(album: album, context: .list)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    VStack(alignment: .leading) {
                        Text(album.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(album.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .navigationTitle(genre.value)
        .overlay {
            if isLoading {
                ProgressView()
            } else if albums.isEmpty {
                ContentUnavailableView("No Albums", systemImage: "music.note")
            }
        }
        .task {
            isLoading = true
            if let fetched = try? await library.loadAlbums(for: genre) {
                self.albums = fetched
            }
            isLoading = false
        }
    }
}
