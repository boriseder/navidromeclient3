import SwiftUI

struct AlbumDetailView: View {
    // FIX: Disambiguate Album
    let album: NavidromeClient3.Album
    
    @Environment(SongManager.self) private var songManager
    @Environment(PlayerViewModel.self) private var player
    @Environment(FavoritesManager.self) private var favoritesManager
    
    @State private var songs: [Song] = []
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AlbumDetailHeaderView(album: album)
                    .padding(.bottom, DSLayout.sectionGap)
                
                if isLoading {
                    ProgressView().padding()
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                            SongRow(song: song, trackNumber: index + 1, isPlaying: player.currentSong?.id == song.id)
                                .onTapGesture {
                                    Task { await player.play(song: song, context: songs) }
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
