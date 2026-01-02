//
//  FavoritesView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Compliance
//  - Fixed missing argument in setPlaylist call
//

import SwiftUI

struct FavoritesView: View {
    @Environment(FavoritesManager.self) var favoritesManager
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(ThemeManager.self) var theme
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                if favoritesManager.favoriteSongs.isEmpty {
                    ContentUnavailableView(
                        "No Favorites",
                        systemImage: "heart.slash",
                        description: Text("Mark songs as favorite to see them here.")
                    )
                } else {
                    List {
                        ForEach(favoritesManager.favoriteSongs) { song in
                            Button {
                                Task {
                                    // Fixed: Added missing albumId parameter
                                    await playerVM.setPlaylist([song], startIndex: 0, albumId: song.albumId)
                                }
                            } label: {
                                SongRow(song: song, context: .favorites)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .padding(.bottom, DSLayout.miniPlayerHeight)
                }
            }
            .navigationTitle("Favorites")
            .refreshable {
                await favoritesManager.loadFavoriteSongs()
            }
        }
        .task {
            if favoritesManager.favoriteSongs.isEmpty {
                await favoritesManager.loadFavoriteSongs()
            }
        }
    }
}
