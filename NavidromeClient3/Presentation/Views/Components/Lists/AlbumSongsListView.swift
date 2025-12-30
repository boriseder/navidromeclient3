//
//  AlbumSongsListView.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Player Call and SongRow usage
//

import SwiftUI

struct AlbumSongsListView: View {
    let songs: [Song]
    let album: Album
    
    @Environment(PlayerViewModel.self) private var player
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                SongRow(
                    song: song,
                    trackNumber: index + 1,
                    isPlaying: player.currentSong?.id == song.id
                )
                .onTapGesture {
                    // FIX: Use playQueue instead of play(context:) to support gapless/next track
                    player.playQueue(songs: songs, startIndex: index)
                }
                
                Divider()
                    .padding(.leading, 40)
            }
        }
    }
}
