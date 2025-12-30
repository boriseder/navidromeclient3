//
//  ArtistImageView.swift
//  NavidromeClient3
//
//  Swift 6: Async Image Loading for Artists
//

import SwiftUI

struct ArtistImageView: View {
    let artist: Artist
    var context: ImageContext = .list // Default context
    
    @Environment(CoverArtManager.self) private var coverArtManager
    
    @State private var image: UIImage?
    @State private var hasError = false
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Placeholder
                ZStack {
                    Color.secondary.opacity(0.1)
                    if hasError {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(artist.name.prefix(1)))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            // Check memory cache first for instant load
            if let cached = coverArtManager.getArtistImage(for: artist.id, context: context) {
                self.image = cached
            }
        }
        .task(id: artist.id) {
            // Async load from disk/network
            if image == nil {
                if let loaded = await coverArtManager.loadArtistImage(for: artist.id, context: context) {
                    self.image = loaded
                } else {
                    self.hasError = true
                }
            }
        }
    }
}
