import SwiftUI

struct AlbumDetailHeaderView: View {
    let album: Album
    
    var body: some View {
        VStack(spacing: DSLayout.contentGap) {
            // FIX: Correct initializer usage matching AlbumImageView
            AlbumImageView(album: album, context: .detail)
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.content))
                .shadow(radius: 10)
            
            // Metadata
            VStack(spacing: DSLayout.tightGap) {
                Text(album.name)
                    .font(DSText.detail)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(album.artist)
                    .font(DSText.detail)
                    .foregroundColor(DSColor.secondary)
                
                HStack(spacing: DSLayout.elementGap) {
                    if let year = album.year {
                        Text(String(year))
                    }
                    if let genre = album.genre {
                        Text("•")
                        Text(genre)
                    }
                }
                .font(DSText.metadata)
                .foregroundColor(DSColor.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSLayout.sectionGap)
    }
}
