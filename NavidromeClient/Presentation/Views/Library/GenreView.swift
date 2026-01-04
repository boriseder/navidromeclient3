//
//  GenreView.swift - RESTORED: Full Swift 5 Functionality
//  NavidromeClient
//
//  Swift 6 Compliance with ALL original features restored
//

import SwiftUI
import Observation

struct GenreView: View {
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(ThemeManager.self) var theme
    @Environment(MusicLibraryManager.self) var musicLibraryManager
    @Environment(NetworkMonitor.self) var networkMonitor
    
    private var offlineManager = OfflineManager.shared
    
    @State private var searchText = ""
    @State private var debouncer = Debouncer()
    
    // Unified state logic
    private var displayedGenres: [Genre] {
        let genres: [Genre]
        
        if networkMonitor.shouldLoadOnlineContent {
            genres = filterGenres(musicLibraryManager.genres)
        } else {
            // Extract unique genres from offline albums
            genres = filterGenres(extractGenresFromAlbums(offlineManager.offlineAlbums))
        }
        
        return genres
    }

    // Add this helper method
    private func extractGenresFromAlbums(_ albums: [Album]) -> [Genre] {
        var genreDict: [String: (albumCount: Int, songCount: Int)] = [:]
        
        for album in albums {
            if let genreString = album.genre {
                // Handle multiple genres separated by semicolons or commas
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
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search genres...")
            .refreshable {
                guard networkMonitor.shouldLoadOnlineContent else { return }
                await refreshAllData()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                    }
                }
            }
            .navigationDestination(for: Genre.self) { genre in
                AlbumCollectionView(context: .byGenre(genre))
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.contentGap) {
                ForEach(displayedGenres.indices, id: \.self) { index in
                    let genre = displayedGenres[index]
                    
                    NavigationLink(value: genre) {
                        GenreRowView(genre: genre, index: index)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, DSLayout.miniPlayerHeight)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, DSLayout.screenPadding)
    }
    
    // MARK: - Business Logic
    
    private func filterGenres(_ genres: [Genre]) -> [Genre] {
        let filteredGenres: [Genre]
        
        if searchText.isEmpty {
            filteredGenres = genres
        } else {
            filteredGenres = genres.filter { genre in
                genre.value.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filteredGenres.sorted(by: { $0.value < $1.value })
    }

    private func refreshAllData() async {
        await musicLibraryManager.refreshAllData()
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            // Search filtering happens automatically via computed property
        }
    }
}

// MARK: - Genre Row View

struct GenreRowView: View {
    let genre: Genre
    let index: Int
   
    @Environment(ThemeManager.self) var theme

    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.2),
                                .white.opacity(0.08),
                                .white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: ImageContext.artistList.displaySize, height: ImageContext.artistList.displaySize)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .white.opacity(0.1), radius: 4, x: 0, y: 2)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: DSLayout.smallIcon))
                    .foregroundStyle(DSColor.onDark)
            }
            .padding(.vertical, DSLayout.tightPadding)
            .padding(.leading, DSLayout.tightPadding)
            
            Text(genre.value)
                .font(DSText.emphasized)
                .foregroundStyle(DSColor.onDark)
                .lineLimit(1)
            
            Spacer()
            
            Image(systemName: "record.circle")
                .font(DSText.fine)
                .foregroundStyle(DSColor.onDark)
            
            Text("\(genre.albumCount) Album\(genre.albumCount != 1 ? "s" : "")")
                .font(DSText.metadata)
                .foregroundStyle(DSColor.onDark)
                .padding(.trailing, DSLayout.contentPadding)
        }
        .background(theme.backgroundContrastColor.opacity(0.12))
    }
}
