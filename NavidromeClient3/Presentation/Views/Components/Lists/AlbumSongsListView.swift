//
//  AlbumSongsListView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 11.09.25.
//

import SwiftUI

// MARK: - Album Songs List
struct AlbumSongsListView: View {
    let songs: [Song]
    let album: Album
    
    @EnvironmentObject var playerVM: PlayerViewModel
    
    var body: some View {
        ForEach(songs.indices, id: \.self) { index in
            let song = songs[index]
            
            SongRow(
                song: song,
                index: index + 1,
                isPlaying: playerVM.currentSong?.id == song.id && playerVM.isPlaying,
                action: {
                    Task { await playerVM.setPlaylist(songs, startIndex: index, albumId: album.id) }
                },
                onMore: {
                    playerVM.stop()
                },
                context: .album
            )
        }
    }
}

