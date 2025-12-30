//
//  AlbumImageView.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Image Loading & Context Storage
//

import SwiftUI

struct AlbumImageView: View {
    @Environment(CoverArtManager.self) private var coverArtManager
    
    let albumId: String
    // FIX: Store the full context so we can use it in .task
    let context: ImageContext
    
    @State private var image: UIImage?
    
    init(albumId: String, size: Int) {
        self.albumId = albumId
        // Fallback context if constructed manually
        self.context = .custom(displaySize: CGFloat(size), scale: 2.0)
    }
    
    // Primary Init
    init(album: NavidromeClient3.Album, context: ImageContext) {
        self.albumId = album.id
        self.context = context
    }
    
    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(DSColor.surfaceLight)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                            .font(.system(size: context.size > 100 ? 40 : 20))
                    }
            }
        }
        .clipped() // Ensure image doesn't bleed out
        .task {
            // FIX: Uncommented and updated to use stored context
            if let loaded = await coverArtManager.loadAlbumImage(for: albumId, context: context) {
                self.image = loaded
            }
        }
    }
}
