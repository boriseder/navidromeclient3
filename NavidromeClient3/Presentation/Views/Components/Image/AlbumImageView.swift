import SwiftUI

struct AlbumImageView: View {
    @Environment(CoverArtManager.self) private var coverArtManager

    let albumId: String
    let context: ImageContext
    
    private var displaySize: CGFloat {
        return context.displaySize
    }
    
    // Helper to extract image if loaded
    private var loadedImage: UIImage? {
        // Since getAlbumImage is async actor call, we can't synchronously check here easily without await.
        // For UI, we rely on the @State 'image' populated by the .task
        return image
    }
    
    @State private var image: UIImage?
    
    // FIX: Clear init
    init(albumId: String, context: ImageContext) {
        self.albumId = albumId
        self.context = context
    }
    
    // Convenience
    init(album: Album, context: ImageContext) {
        self.init(albumId: album.id, context: context)
    }
    
    // Convenience for raw size -> Custom Context
    init(albumId: String, size: Int) {
        self.init(
            albumId: albumId,
            context: .custom(displaySize: CGFloat(size), scale: UIScreen.main.scale)
        )
    }
        
    var body: some View {
        ZStack {
            placeholderView
                .opacity(image != nil ? 0 : 1)
            
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: displaySize, height: displaySize)
                    .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                    .transition(.opacity)
            }
        }
        .frame(width: displaySize, height: displaySize)
        .task(id: albumId) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        // Attempt load
        self.image = await coverArtManager.loadAlbumImage(for: albumId, context: context)
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: DSCorners.element)
            .fill(
                LinearGradient(
                    colors: [.orange, .pink.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: displaySize, height: displaySize)
            .overlay {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: DSLayout.icon))
                    .foregroundStyle(.white.opacity(0.6))
            }
    }
}
