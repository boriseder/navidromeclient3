import SwiftUI

struct HeartButton: View {
    let song: Song
    
    // FIX: Swift 6 Environment
    @Environment(FavoritesManager.self) private var favoritesManager
    
    var body: some View {
        Button {
            Task {
                await favoritesManager.toggleFavorite(song: song)
            }
        } label: {
            Image(systemName: favoritesManager.isFavorite(songId: song.id) ? "heart.fill" : "heart")
                .foregroundStyle(favoritesManager.isFavorite(songId: song.id) ? .red : .primary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain) // Standard style, removed custom inferrence causing issues
    }
}
