//
//  ArtistImageView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Modern Concurrency (Task.sleep)
//

import SwiftUI

struct ArtistImageView: View {
    @Environment(CoverArtManager.self) var coverArtManager
    
    let artist: Artist
    let context: ImageContext
    
    // Mirror AlbumImageView: local state forces redraw on arrival
    @State private var image: UIImage?
    
    private var displaySize: CGFloat {
        return context.displaySize
    }
    
    init(artist: Artist, context: ImageContext) {
        self.artist = artist
        self.context = context
    }
    
    var body: some View {
        ZStack {
            placeholderView
                .opacity(image != nil ? 0 : 1)
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: displaySize, height: displaySize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(DSColor.onLight.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: DSColor.onLight.opacity(0.1), radius: 4, x: 0, y: 2)
                    .transition(.opacity)
            }
        }
        .frame(width: displaySize, height: displaySize)
        .animation(.easeInOut(duration: 0.3), value: image != nil)
        .task(id: "\(artist.id)_\(context.size)") {
            if let cached = coverArtManager.imageCache.cachedImage(
                for: artist.id, type: .artist, size: context.size
            ) {
                self.image = cached
                return
            }
            self.image = await coverArtManager.loadArtistImage(for: artist.id, context: context)
        }
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
            .frame(width: displaySize, height: displaySize)
            .overlay(placeholderOverlay)
    }
    
    @ViewBuilder
    private var placeholderOverlay: some View {
        if coverArtManager.isLoadingImage(for: artist.id, size: context.size) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if let _ = coverArtManager.getImageError(for: artist.id, size: context.size) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DSLayout.smallIcon))
                .foregroundStyle(.white.opacity(0.8))
        } else {
            Image(systemName: "music.mic")
                .font(.system(size: DSLayout.icon))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
