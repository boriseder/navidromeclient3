//
//  ArtistImageView.swift
//  NavidromeClient
//
//  OPTIMIZED: Context-aware image loading with caching and preload support
//

import SwiftUI

struct ArtistImageView: View {
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    let artist: Artist
    let context: ImageContext
    
    private var displaySize: CGFloat {
        return context.displaySize
    }
    
    private var hasImage: Bool {
        coverArtManager.getArtistImage(for: artist.id, context: context) != nil
    }
    
    init(artist: Artist, context: ImageContext) {
        self.artist = artist
        self.context = context
    }
    
    var body: some View {
        ZStack {
            placeholderView
                .opacity(hasImage ? 0 : 1)
            
            if let image = coverArtManager.getArtistImage(for: artist.id, context: context) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: displaySize, height: displaySize)
                    .clipShape(Circle())
                    .opacity(hasImage ? 1 : 0)
                    .transition(.opacity)
                    .overlay(
                        Circle()
                            .stroke(DSColor.onLight.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: DSColor.onLight.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
        .frame(width: displaySize, height: displaySize)
        .animation(.easeInOut(duration: 0.3), value: hasImage)
        .task(id: "\(artist.id)_\(context.size)_\(coverArtManager.cacheGeneration)") {
            // Früher Return bei Cache-Hit
            if coverArtManager.getArtistImage(for: artist.id, context: context) != nil {
                return  // Bild bereits im Cache
            }
            
            // NUR bei kleinen Bildern verzögern, Fullscreen sofort laden
            if context.size < ImageContext.fullscreen.size {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
                
                // Nochmal prÃ¼fen nach VerzÃ¶gerung
                if coverArtManager.getArtistImage(for: artist.id, context: context) != nil {
                    return
                }
            }
            
            await coverArtManager.loadArtistImage(
                for: artist.id,
                context: context
            )
        }
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        Circle()  // ✅ Runder Placeholder für Artists
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
        } else if let error = coverArtManager.getImageError(for: artist.id, size: context.size) {
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
