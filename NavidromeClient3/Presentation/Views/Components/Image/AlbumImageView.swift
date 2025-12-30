//
//  AlbumImageView.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Ambiguous Init & Module types
//

import SwiftUI

struct AlbumImageView: View {
    @Environment(CoverArtManager.self) private var coverArtManager
    
    let albumId: String
    let context: ImageContext
    
    @State private var image: UIImage?
    
    // Init 1: Manual ID (used by Lists sometimes)
    init(albumId: String, size: CGFloat) {
        self.albumId = albumId
        self.context = .custom(displaySize: size, scale: 2.0)
    }
    
    // Init 2: From Album Model (used by Headers)
    // FIX: Removed 'NavidromeClient3.' prefix to avoid module lookup issues
    init(album: Album, context: ImageContext) {
        self.albumId = album.coverArt ?? album.id
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
                    .fill(Color.gray.opacity(0.2)) // DSColor.surfaceLight replacement
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                            .font(.system(size: context.displaySize > 100 ? 40 : 20))
                    }
            }
        }
        .clipped()
        .task(id: albumId) {
            // Load image when ID changes
            if let loaded = await coverArtManager.loadAlbumImage(for: albumId, context: context) {
                self.image = loaded
            }
        }
    }
}
