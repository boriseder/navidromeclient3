//
//  ArtistImageView.swift
//  NavidromeClient
//
//  Swift 6: @Environment & Deprecation Fixes
//

import SwiftUI

struct ArtistImageView: View {
    @Environment(CoverArtManager.self) private var coverArtManager
    
    let artistId: String
    let context: ImageContext
    
    @State private var image: UIImage?
    
    // Standard Init
    init(artist: Artist, context: ImageContext) {
        self.artistId = artist.id
        self.context = context
    }
    
    // Convenience Init with size (Fixes Deprecation)
    init(artist: Artist, size: Int) {
        self.artistId = artist.id
        
        // FIX: Use UITraitCollection.current.displayScale instead of UIScreen.main
        // If 0 (unknown), default to 2.0 (standard Retina)
        let scale = UITraitCollection.current.displayScale > 0 ? UITraitCollection.current.displayScale : 2.0
        
        self.context = .custom(displaySize: CGFloat(size), scale: scale)
    }
    
    var body: some View {
        ZStack {
            placeholderView
                .opacity(image != nil ? 0 : 1)
            
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: context.displaySize, height: context.displaySize)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(DSColor.onLight.opacity(0.1), lineWidth: 1)
                    )
            }
        }
        .frame(width: context.displaySize, height: context.displaySize)
        .task(id: artistId) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        // Attempt load via manager
        self.image = await coverArtManager.loadArtistImage(for: artistId, context: context)
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.blue, .purple.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: context.displaySize, height: context.displaySize)
            .overlay {
                Image(systemName: "music.mic")
                    .font(.system(size: DSLayout.icon))
                    .foregroundStyle(.white.opacity(0.6))
            }
    }
}
