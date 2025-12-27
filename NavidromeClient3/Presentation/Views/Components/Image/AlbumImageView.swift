import SwiftUI

struct AlbumImageView: View {
    let albumId: String
    let size: Int
    
    // FIX: Swift 6 Environment
    @Environment(CoverArtManager.self) private var coverArtManager
    
    @State private var image: UIImage?
    
    // Convenience init if you have the full Album object
    init(album: Album, context: ImageContext) {
        self.albumId = album.id
        // We use the context logic (MainActor safe) to determine size
        self.size = context.size
    }
    
    init(albumId: String, size: Int) {
        self.albumId = albumId
        self.size = size
    }
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(DSColor.surfaceLight) // Using DesignSystem
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .task(id: albumId) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        let ctx = ImageContext(size: size)
        self.image = await coverArtManager.loadAlbumImage(for: albumId, context: ctx)
    }
}
