//
//  AlbumSongsListView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Environment(Type.self)
//

import SwiftUI

struct AlbumSongsListView: View {
    let songs: [Song]
    let albumId: String
    
    @Environment(PlayerViewModel.self) var playerVM
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(songs.indices, id: \.self) { index in
                let song = songs[index]
                
                Button {
                    Task {
                        await playerVM.setPlaylist(songs, startIndex: index, albumId: albumId)
                    }
                } label: {
                    SongRow(song: song, context: .album)
                        .padding(.horizontal, DSLayout.contentPadding)
                }
                .buttonStyle(PlainButtonStyle())
                
                if index < songs.count - 1 {
                    Divider()
                        .padding(.leading, 40)
                        .opacity(0.5)
                }
            }
        }
    }
}
