import SwiftUI

struct HeartButton: View {
    let song: Song
    @Environment(FavoritesManager.self) private var favoritesManager
    
    var body: some View {
        Button {
            Task { await favoritesManager.toggleFavorite(song: song) }
        } label: {
            Image(systemName: favoritesManager.isFavorite(songId: song.id) ? "heart.fill" : "heart")
                .foregroundColor(favoritesManager.isFavorite(songId: song.id) ? .red : .primary)
        }
    }
}
