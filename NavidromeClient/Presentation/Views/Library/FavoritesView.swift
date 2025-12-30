import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var theme: ThemeManager

    @StateObject private var debouncer = Debouncer()
    @State private var searchText = ""
    @State private var showingClearConfirmation = false
    @State private var selection = 0

    private var displayedSongs: [Song] {
        let songs: [Song]
        switch networkMonitor.contentLoadingStrategy {
        case .online:
            songs = favoritesManager.favoriteSongs
        case .offlineOnly:
            songs = favoritesManager.favoriteSongs.filter { song in
                DownloadManager.shared.isSongDownloaded(song.id)
            }
        case .setupRequired:
            songs = []
        }
        
        if searchText.isEmpty {
            return songs
        } else {
            return songs.filter { song in
                let titleMatches = song.title.localizedCaseInsensitiveContains(searchText)
                let artistMatches = (song.artist ?? "").localizedCaseInsensitiveContains(searchText)
                let albumMatches = (song.album ?? "").localizedCaseInsensitiveContains(searchText)
                return titleMatches || artistMatches || albumMatches
            }
        }
    }
        
    var body: some View {
        NavigationStack {
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    Picker("Category", selection: $selection) {
                        Text("Songs").tag(0)
                        Text("Playlists").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if selection == 0 {
                        contentView
                    } else {
                        Text("Playlists selected")
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Your Favorites")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .refreshable {
                guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
                await refreshFavorites()
            }
            .task {
                await favoritesManager.loadFavoriteSongs()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { Task { await playAllFavorites() } } label: { Label("Play All", systemImage: "play.fill") }
                        Button { Task { await shuffleAllFavorites() } } label: { Label("Shuffle All", systemImage: "shuffle") }
                        
                        if networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent {
                            Divider()
                            Button(role: .destructive) { showingClearConfirmation = true } label: { Label("Clear All Favorites", systemImage: "trash") }
                        }
                        Divider()
                        NavigationLink(destination: SettingsView()) { Label("Settings", systemImage: "person.crop.circle.fill") }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .alert("Clear All Favorites?", isPresented: $showingClearConfirmation) {
                Button("Clear", role: .destructive) { Task { await clearAllFavorites() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all songs from your favorites.")
            }
        }
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
                
                ForEach(displayedSongs.indices, id: \.self) { index in
                    let song = displayedSongs[index]
                    SongRow(
                        song: song,
                        index: index + 1,
                        isPlaying: playerVM.currentSong?.id == song.id && playerVM.isPlaying,
                        action: { Task { await playerVM.setPlaylist(displayedSongs, startIndex: index, albumId: nil) } },
                        onMore: { },
                        favoriteAction: { Task { await favoritesManager.toggleFavorite(song) } },
                        context: .favorites
                    )
                }
            }
            .padding(.bottom, DSLayout.miniPlayerHeight)
            .padding(.horizontal, DSLayout.screenPadding)
        }
    }
    
    private func refreshFavorites() async {
        await favoritesManager.loadFavoriteSongs(forceRefresh: true)
    }
    
    private func playAllFavorites() async {
        guard !displayedSongs.isEmpty else { return }
        await playerVM.setPlaylist(displayedSongs, startIndex: 0, albumId: nil)
    }
    
    private func shuffleAllFavorites() async {
        guard !displayedSongs.isEmpty else { return }
        let shuffledSongs = displayedSongs.shuffled()
        await playerVM.setPlaylist(shuffledSongs, startIndex: 0, albumId: nil)
        if !playerVM.isShuffling { playerVM.toggleShuffle() }
    }
    
    private func clearAllFavorites() async {
        await favoritesManager.clearAllFavorites()
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce { }
    }
}
