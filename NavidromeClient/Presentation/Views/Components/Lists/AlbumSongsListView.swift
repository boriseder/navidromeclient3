//
//  AlbumSongsListView.swift
//  NavidromeClient
//
//  UPDATED: Konsistenz mit SongRow & Refactored Layout
//

import SwiftUI
import Observation

struct AlbumSongsListView: View {
    let songs: [Song]
    let albumId: String
    
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(FavoritesManager.self) var favoritesManager
    
    var body: some View {
        // Kein LazyVStack hier, da wir bereits im ListLayoutWrapper sind
        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
            let isThisSongPlaying = playerVM.currentSong?.id == song.id && playerVM.isPlaying
            
            SongRow(
                song: song,
                index: index + 1,
                isPlaying: isThisSongPlaying,
                action: {
                    Task {
                        await playerVM.setPlaylist(songs, startIndex: index, albumId: albumId)
                    }
                },
                favoriteAction: {
                    Task {
                        await favoritesManager.toggleFavorite(song)
                    }
                },
                context: .album,
                isLastInGroup: index == songs.count - 1,
                isFavorited: favoritesManager.isFavorite(song.id)
            )
            
            if index < songs.count - 1 {
                Divider()
                    .padding(.leading, DSLayout.largeGap) // Platz für das Album-Thumbnail der SongRow lassen
                    .opacity(0.3)
            }
        }
    }
}
