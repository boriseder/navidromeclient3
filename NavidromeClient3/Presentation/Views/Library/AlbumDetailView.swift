//
//  AlbumDetailView.swift
//  NavidromeClient
//
//  Swift 6: Detail View Migration
//

import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    
    @Environment(SongManager.self) private var songManager
    @Environment(PlayerViewModel.self) private var player
    @Environment(FavoritesManager.self) private var favoritesManager
    
    @State private var songs: [Song] = []
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                AlbumDetailHeaderView(album: album)
                    .padding(.bottom, DSLayout.sectionGap)
                
                // Song List
                if isLoading {
                    ProgressView().padding()
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                            SongRow(
                                song: song,
                                trackNumber: index + 1,
                                isPlaying: player.currentSong?.id == song.id
                            )
                            .onTapGesture {
                                Task {
                                    await player.play(song: song, context: songs)
                                }
                            }
                            // Context Menu for actions
                            .contextMenu {
                                Button {
                                    Task { await favoritesManager.toggleFavorite(song: song) }
                                } label: {
                                    Label(
                                        favoritesManager.isFavorite(songId: song.id) ? "Unfavorite" : "Favorite",
                                        systemImage: favoritesManager.isFavorite(songId: song.id) ? "heart.fill" : "heart"
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isLoading = true
            self.songs = await songManager.getSongs(for: album.id)
            isLoading = false
        }
    }
}
