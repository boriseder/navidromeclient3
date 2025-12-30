//
//  FavoritesView.swift
//  NavidromeClient3
//
//  Swift 6: Fixed - Added Tap Handling
//

import SwiftUI

struct FavoritesView: View {
    @Environment(OfflineManager.self) private var offlineManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(AppConfig.self) private var appConfig
    @Environment(FavoritesManager.self) private var favoritesManager
    @Environment(ThemeManager.self) private var theme

    @State private var debouncer = Debouncer(delay: 0.5)
    
    var body: some View {
        List {
            ForEach(favoritesManager.starredSongsList) { song in
                SongRow(song: song, trackNumber: nil, isPlaying: playerVM.currentSong?.id == song.id)
                    .contentShape(Rectangle()) // Ensure entire row is tappable
                    .onTapGesture {
                        playerVM.play(song: song)
                    }
            }
        }
        .searchable(text: $debouncer.input)
        .navigationTitle("Favorites")
        .task {
            if networkMonitor.shouldLoadOnlineContent {
                await favoritesManager.loadFavoriteSongs()
            }
        }
        .refreshable {
             if networkMonitor.shouldLoadOnlineContent {
                await favoritesManager.loadFavoriteSongs()
            }
        }
    }
}
