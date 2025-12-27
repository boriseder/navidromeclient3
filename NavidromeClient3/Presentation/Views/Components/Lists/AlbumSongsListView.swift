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
                    Task {
                        await player.play(song: song, context: songs)
                    }
                }
            }
        }
    }
}
