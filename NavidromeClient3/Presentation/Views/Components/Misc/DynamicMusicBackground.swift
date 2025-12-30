//
//  DynamicMusicBackground.swift
//  NavidromeClient3
//
//  Swift 6: Added Blurred Album Art Support
//

import SwiftUI

struct DynamicMusicBackground: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(CoverArtManager.self) private var coverArtManager
    
    // Optional ID to load the background image
    var albumId: String?

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            // 1. Fallback / Base Gradient (Theme)
            LinearGradient(
                colors: [
                    theme.accent.opacity(0.1),
                    theme.accent.opacity(0.05),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // 2. Blurred Image Layer
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .blur(radius: 60, opaque: true) // Heavy blur
                    .overlay(Color.black.opacity(0.5)) // Dimming for text contrast
                    .transition(.opacity.animation(.easeInOut(duration: 0.6)))
            }
            
            // 3. Subtle Texture (Grain)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.02),
                            .clear,
                            .black.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
        .task(id: albumId) {
            guard let id = albumId else {
                withAnimation { self.image = nil }
                return
            }
            
            // Fetch a moderate size image for the blur (500px is plenty)
            let context = ImageContext.custom(displaySize: 500, scale: 1.0)
            
            if let loaded = await coverArtManager.loadAlbumImage(for: id, context: context) {
                withAnimation {
                    self.image = loaded
                }
            }
        }
    }
}
