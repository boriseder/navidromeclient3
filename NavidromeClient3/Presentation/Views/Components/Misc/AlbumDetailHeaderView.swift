import SwiftUI

struct AlbumDetailHeaderView: View {
    // FIX: Disambiguate Album
    let album: NavidromeClient3.Album
    
    var body: some View {
        VStack(spacing: DSLayout.contentGap) {
            // FIX: Using correct initializer labels now that ambiguity is resolved
            AlbumImageView(album: album, context: .detail)
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.content))
                .shadow(radius: 10)
            
            VStack(spacing: DSLayout.tightGap) {
                Text(album.name)
                    .font(DSText.fine)
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
