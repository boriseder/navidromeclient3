import SwiftUI

struct FavoritesView: View {
    // FIX: Swift 6 Environment
    @Environment(OfflineManager.self) private var offlineManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(AppConfig.self) private var appConfig
    @Environment(FavoritesManager.self) private var favoritesManager
    @Environment(ThemeManager.self) private var theme

    // FIX: Debouncer is @Observable, use @State
    @State private var debouncer = Debouncer(delay: 0.5)
    
    var body: some View {
        List {
            ForEach(favoritesManager.starredSongsList) { song in
                SongRow(song: song, trackNumber: nil, isPlaying: false)
            }
        }
        .searchable(text: $debouncer.input)
        .navigationTitle("Favorites")
        .task {
            await favoritesManager.loadFavoriteSongs()
        }
    }
}
