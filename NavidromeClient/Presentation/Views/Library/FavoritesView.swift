//
//  FavoritesView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.01.26.
//


//
//  FavoritesView.swift - FIXED: Compiler Errors Resolved
//  NavidromeClient
//
//  Swift 6 Compliance with ALL original features restored
//

import SwiftUI
import Observation

struct FavoritesView: View {
    @Environment(OfflineManager.self) var offlineManager
    @Environment(NetworkMonitor.self) var networkMonitor
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(FavoritesManager.self) var favoritesManager
    @Environment(ThemeManager.self) var theme
    @Environment(DownloadManager.self) var downloadManager
    
    @State private var debouncer: Debouncer = Debouncer()
    @State private var searchText: String = ""
    @State private var showingClearConfirmation: Bool = false
    @State private var selection: Int = 0
    @State private var filteredSongs: [Song] = []
    @State private var baseSongs: [Song] = []
        
    var body: some View {
        makeNavigationStack()
    }
    
    @ViewBuilder
    private func makeNavigationStack() -> some View {
        NavigationStack {
            makeMainContent()
                .navigationTitle("Your Favorites")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(.clear, for: .navigationBar)
                .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
                .searchable(text: $searchText, prompt: "Search favorites...")
                .refreshable {
                    await handleRefresh()
                }
                .task {
                    await handleTask()
                }
                .onChange(of: searchText) { _, _ in
                    handleSearchTextChange()
                }
                .onChange(of: favoritesManager.favoriteSongs.count) { _, _ in
                    updateFilteredSongs()
                }
                .onChange(of: networkMonitor.contentLoadingStrategy) { _, _ in
                    updateFilteredSongs()
                }
                .navigationDestination(for: Album.self) { album in
                    AlbumDetailView(album: album)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        makeMenu()
                    }
                }
                .alert("Clear All Favorites?", isPresented: $showingClearConfirmation) {
                    makeAlert()
                } message: {
                    Text("This will remove all songs from your favorites.")
                }
        }
    }
    
    @ViewBuilder
    private func makeMainContent() -> some View {
        ZStack {
            if theme.backgroundStyle == .dynamic {
                DynamicMusicBackground()
            }
            
            contentView
        }
    }
    
    @ViewBuilder
    private func makeMenu() -> some View {
        Menu {
            Button {
                Task { await playAllFavorites() }
            } label: {
                Label("Play All", systemImage: "play.fill")
            }
            
            Button {
                Task { await shuffleAllFavorites() }
            } label: {
                Label("Shuffle All", systemImage: "shuffle")
            }
                
            if networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent {
                Divider()
                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("Clear All Favorites", systemImage: "trash")
                }
            }
            
            Divider()
            NavigationLink(destination: SettingsView()) {
                Label("Settings", systemImage: "person.crop.circle.fill")
            }
            
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(theme.textColor)
        }
    }
    
    @ViewBuilder
    private func makeAlert() -> some View {
        Button("Clear", role: .destructive) {
            Task { await clearAllFavorites() }
        }
        Button("Cancel", role: .cancel) {}
    }
    
    private func handleRefresh() async {
        guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
        await refreshFavorites()
    }
    
    private func handleTask() async {
        await favoritesManager.loadFavoriteSongs()
        updateFilteredSongs()
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                if favoritesManager.favoriteSongs.isEmpty {
                    Text("No favorites available")
                        .font(DSText.sectionTitle)
                        .padding(.top, DSLayout.tightGap)
                        .padding(.bottom, DSLayout.sectionGap)
                }
                
                let songs = filteredSongs
                ForEach(Array(songs.enumerated()), id: \.0) { index, song in
                    let isCurrentlyPlaying = playerVM.currentSong?.id == song.id && playerVM.isPlaying
                    let isLast = index == songs.count - 1
                    
                    SongRow(
                        song: song,
                        index: index + 1,
                        isPlaying: isCurrentlyPlaying,
                        action: {
                            Task {
                                await playerVM.setPlaylist(
                                    songs,
                                    startIndex: index,
                                    albumId: nil
                                )
                            }
                        },
                        favoriteAction: {
                            Task {
                                await favoritesManager.toggleFavorite(song)
                            }
                        },
                        context: .favorites,
                        isLastInGroup: isLast,
                        isFavorited: true
                    )
                }
            }
            .padding(.bottom, DSLayout.miniPlayerHeight)
            .padding(.horizontal, DSLayout.screenPadding)
        }
    }
    
    
    // MARK: - Business Logic
    
    private func updateBaseSongs() {
        let allFavorites: [Song] = favoritesManager.favoriteSongs
        
        // Check if we should load online content
        let monitor: NetworkMonitor = networkMonitor
        let strategy: ContentLoadingStrategy = monitor.contentLoadingStrategy
        let shouldLoadOnline: Bool = strategy.shouldLoadOnlineContent
        
        if shouldLoadOnline {
            baseSongs = allFavorites
            return
        }
        
        // Filter for downloaded songs only
        var downloaded: [Song] = []
        let manager: DownloadManager = downloadManager
        
        for song in allFavorites {
            let songId: String = song.id
            let isDownloaded: Bool = manager.isSongDownloaded(songId)
            if isDownloaded {
                downloaded.append(song)
            }
        }
        
        baseSongs = downloaded
    }
    
    private func updateFilteredSongs() {
        updateBaseSongs()
        
        let songs: [Song] = baseSongs
        
        if searchText.isEmpty {
            filteredSongs = songs
            return
        }
        
        var filtered: [Song] = []
        for song in songs {
            let titleMatch = song.title.localizedCaseInsensitiveContains(searchText)
            let artistMatch = (song.artist ?? "").localizedCaseInsensitiveContains(searchText)
            let albumMatch = (song.album ?? "").localizedCaseInsensitiveContains(searchText)
            
            if titleMatch || artistMatch || albumMatch {
                filtered.append(song)
            }
        }
        filteredSongs = filtered
    }
    
    private func refreshFavorites() async {
        await favoritesManager.loadFavoriteSongs(forceRefresh: true)
    }
    
    private func playAllFavorites() async {
        guard !filteredSongs.isEmpty else { return }
        await playerVM.setPlaylist(filteredSongs, startIndex: 0, albumId: nil)
    }
    
    private func shuffleAllFavorites() async {
        guard !filteredSongs.isEmpty else { return }
        let shuffledSongs = filteredSongs.shuffled()
        await playerVM.setPlaylist(shuffledSongs, startIndex: 0, albumId: nil)
        if !playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }
    
    private func clearAllFavorites() async {
        await favoritesManager.clearAllFavorites()
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            updateFilteredSongs()
        }
    }
}
