import SwiftUI

struct ArtistImageView: View {
    let artist: Artist
    let size: Int
    
    @Environment(CoverArtManager.self) private var coverArtManager
    @State private var image: UIImage?
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Circle()
                    .fill(DSColor.surfaceLight)
                    .overlay {
                        Text(String(artist.name.prefix(1)))
                            .font(.headline)
                    }
            }
        }
        .task(id: artist.id) {
            // Placeholder: Assume generic cover art fetch works for artists if configured
            // Or implement specific getArtistImage in CoverArtManager
            // For now, we fallback to text
        }
    }
}
