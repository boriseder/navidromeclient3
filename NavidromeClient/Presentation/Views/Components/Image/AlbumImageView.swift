//
//  AlbumImageView.swift
//  NavidromeClient
//
//  Context-aware image loading with automatic Retina support
//  Images now request proper pixel sizes based on display scale
//

import SwiftUI

struct AlbumImageView: View {
    @EnvironmentObject var coverArtManager: CoverArtManager

    let album: Album
    let context: ImageContext
    
    private var displaySize: CGFloat {
        return context.displaySize
    }
    
    private var hasImage: Bool {
        coverArtManager.getAlbumImage(for: album.id, context: context) != nil
    }
    
    init(album: Album, context: ImageContext) {
        self.album = album
        self.context = context
    }
        
    var body: some View {
        ZStack {
            placeholderView
                .opacity(hasImage ? 0 : 1)
            
            if let image = coverArtManager.getAlbumImage(for: album.id, context: context) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: displaySize, height: displaySize)
                    .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                    .opacity(hasImage ? 1 : 0)
                    .transition(.opacity)
            }
        }
        .frame(width: displaySize, height: displaySize)
        .animation(.easeInOut(duration: 0.3), value: hasImage)
        .task(id: "\(album.id)_\(context.size)_\(coverArtManager.cacheGeneration)") {
            // Früher Return bei Cache-Hit
            if coverArtManager.getAlbumImage(for: album.id, context: context) != nil {
                return  // Bild bereits da
            }
            
            // Kleine Verzögerung, damit Preload Vorrang hat
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            
            // Nochmal prüfen nach Verzögerung
            if coverArtManager.getAlbumImage(for: album.id, context: context) != nil {
                return
            }
            
            await coverArtManager.loadAlbumImage(
                for: album.id,
                context: context
            )
        }
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
            .overlay(placeholderOverlay)
    }
    
    @ViewBuilder
    private var placeholderOverlay: some View {
        if coverArtManager.isLoadingImage(for: album.id, size: context.size) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if let error = coverArtManager.getImageError(for: album.id, size: context.size) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DSLayout.smallIcon))
                .foregroundStyle(.white.opacity(0.8))
        } else {
            Image(systemName: "record.circle.fill")
                .font(.system(size: DSLayout.icon))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - Usage Examples
/*
 Verwendung in deinen Views - KEINE Änderungen nötig!
 
 ```swift
 // List View - lädt jetzt automatisch ~240px auf 3x Display
 AlbumImageView(album: album, context: .list)
 
 // Grid View - lädt jetzt automatisch ~600px auf 3x Display
 AlbumImageView(album: album, context: .grid)
 
 // Detail View - lädt jetzt automatisch ~1200px auf 3x Display
 AlbumImageView(album: album, context: .detail)
 
 // Fullscreen - lädt jetzt automatisch 1500px (Navidrome Max)
 AlbumImageView(album: album, context: .fullscreen)
 ```
 
 Die Retina-Unterstützung funktioniert jetzt automatisch! 🎉
 */
