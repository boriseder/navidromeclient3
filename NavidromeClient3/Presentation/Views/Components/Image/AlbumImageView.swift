import SwiftUI

struct AlbumImageView: View {
    @Environment(CoverArtManager.self) private var coverArtManager
    let albumId: String
    let size: Int
    
    init(albumId: String, size: Int) {
        self.albumId = albumId
        self.size = size
    }
    
    // FIX: Using NavidromeClient3.Album to resolve ambiguity
    init(album: NavidromeClient3.Album, context: ImageContext) {
        self.albumId = album.id
        self.size = context.size
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(DSColor.surfaceLight)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                }
        }
        .task {
            // await coverArtManager.loadAlbumImage(for: albumId, context: .custom(displaySize: CGFloat(size), scale: 2.0))
        }
    }
}
