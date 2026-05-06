//
//  AlbumImageView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Compliance
//  - FIXED: Observation bug (View didn't update after load)
//  - Uses @State to force redraw upon image arrival
//

import SwiftUI

struct AlbumImageView: View {
    @Environment(CoverArtManager.self) var coverArtManager
    
    // Support both full album objects and raw IDs
    private let album: Album?
    private let rawAlbumId: String?
    
    let context: ImageContext
    
    @State private var image: UIImage?
    
    private var displaySize: CGFloat {
        return context.displaySize
    }
    
    private var targetAlbumId: String {
        return album?.id ?? rawAlbumId ?? ""
    }
    
    init(album: Album, context: ImageContext) {
        self.album = album
        self.rawAlbumId = nil
        self.context = context
    }
    
    // BUG 13: New initializer to prevent fake Album object creation
    init(albumId: String, context: ImageContext) {
        self.album = nil
        self.rawAlbumId = albumId
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
                    .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                    .transition(.opacity)
            }
        }
        .frame(width: displaySize, height: displaySize)
        .animation(.easeInOut(duration: 0.3), value: image != nil)
        .task(id: "\(targetAlbumId)_\(context.size)") {
            // Fast path: check actor memory cache
            if let cached = await coverArtManager.imageCache.cachedImage(
                for: targetAlbumId, type: .album, size: context.size
            ) {
                self.image = cached
                return
            }
            // Slow path: disk → network
            self.image = await coverArtManager.loadAlbumImage(for: targetAlbumId, context: context)
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
    
    // Update the placeholderOverlay
    @ViewBuilder
    private var placeholderOverlay: some View {
        if coverArtManager.isLoadingImage(for: targetAlbumId, size: context.size) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if let _ = coverArtManager.getImageError(for: targetAlbumId, size: context.size) {
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
