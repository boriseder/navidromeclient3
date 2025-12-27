import SwiftUI

struct AlbumImageView: View {
    @Environment(CoverArtManager.self) private var coverArtManager
    let albumId: String
    let size: Int
    
    init(albumId: String, size: Int) {
        self.albumId = albumId
        self.size = size
    }
    
    // Convenience
    init(album: Album, context: ImageContext) {
        self.albumId = album.id
        self.size = context.size // @MainActor safe access in View init? No, computed property.
                                 // Better to pass context or use task.
    }
    
    var body: some View {
        // Implementation
        Rectangle().fill(Color.gray)
            .task {
                // await coverArtManager.load...
            }
    }
}
