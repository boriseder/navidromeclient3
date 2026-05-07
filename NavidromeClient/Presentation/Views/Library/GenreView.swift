//
//  GenreView.swift
//  NavidromeClient
//
//  UPDATED: Phase 3.2 Refactoring (ListLayoutWrapper + EntityRow)
//  Orientiert am Design der SongRow & strikte Nutzung des DesignSystem
//

import SwiftUI
import Observation

struct GenreView: View {
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(ThemeManager.self) var theme
    @Environment(MusicLibraryManager.self) var musicLibraryManager
    @Environment(NetworkMonitor.self) var networkMonitor
    @Environment(OfflineManager.self) var offlineManager

    @State private var searchText = ""
    @State private var debouncer = Debouncer()
    
    private var displayedGenres: [Genre] {
        let genres: [Genre]
        
        if networkMonitor.canLoadOnlineContent {
            genres = filterGenres(musicLibraryManager.genres)
        } else {
            // Genres aus Offline-Alben extrahieren
            genres = filterGenres(extractGenresFromAlbums(offlineManager.offlineAlbums))
        }
        
        return genres
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if theme.backgroundStyle == .dynamic {
                    DynamicMusicBackground()
                }
                
                contentView
            }
            .navigationTitle("Genres")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Genre.self) { genre in
                AlbumCollectionView(context: .byGenre(genre))
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(album: album)
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search genres...")
            .refreshable {
                guard networkMonitor.canLoadOnlineContent else { return }
                await musicLibraryManager.refreshAllData()
            }
            .onChange(of: searchText) { _, _ in
                debouncer.debounce { }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(theme.textColor)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        // Nutzt den zentralen Layout-Wrapper (Spacing ist standardmäßig tightGap)
        ListLayoutWrapper {
            ForEach(displayedGenres, id: \.value) { genre in
                NavigationLink(value: genre) {
                    GenreListRow(genre: genre)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Business Logic (Unverändert)
    
    private func filterGenres(_ genres: [Genre]) -> [Genre] {
        let filtered = searchText.isEmpty ? genres : genres.filter {
            $0.value.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.sorted(by: { $0.value < $1.value })
    }

    private func extractGenresFromAlbums(_ albums: [Album]) -> [Genre] {
        var genreDict: [String: (albumCount: Int, songCount: Int)] = [:]
        
        for album in albums {
            if let genreString = album.genre {
                let genreNames = genreString.components(separatedBy: CharacterSet(charactersIn: ";,"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                
                for genreName in genreNames {
                    let existing = genreDict[genreName] ?? (albumCount: 0, songCount: 0)
                    genreDict[genreName] = (
                        albumCount: existing.albumCount + 1,
                        songCount: existing.songCount + (album.songCount ?? 0)
                    )
                }
            }
        }
        
        return genreDict.map { Genre(value: $0.key, songCount: $0.value.songCount, albumCount: $0.value.albumCount) }
    }
}

// MARK: - Genre Row Komponente

struct GenreListRow: View {
    let genre: Genre
    
    var body: some View {
        EntityRow(
            title: genre.value,
            leading: {
                // Das Genre-Icon behält seinen spezifischen Look,
                // nutzt aber die Standardmaße (48x48)
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.4),
                                    .white.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.8), lineWidth: 1)
                        )
                    
                    Image(systemName: "music.note.list")
                        .font(.system(size: DSLayout.smallIcon))
                        .foregroundStyle(DSColor.onDark)
                }
            },
            trailing: {
                HStack(spacing: DSLayout.tightGap) {
                    Image(systemName: "record.circle")
                        .font(DSText.fine)
                    
                    Text("\(genre.albumCount) Album\(genre.albumCount != 1 ? "s" : "")")
                        .font(DSText.metadata)
                }
                .foregroundStyle(DSColor.onDark)
            }
        )
    }
}
