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

    let album: Album
    let context: ImageContext
    
    // Fix: Local state to force UI update when data arrives
    @State private var image: UIImage?
    
    private var displaySize: CGFloat {
        return context.displaySize
    }
    
    init(album: Album, context: ImageContext) {
        self.album = album
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
        .task(id: "\(album.id)_\(context.size)") {
            // 1. Check Memory Cache immediately (Fast Path)
            if let cached = coverArtManager.getAlbumImage(for: album.id, context: context) {
                self.image = cached
                return
            }
            
            // 2. Load (Disk -> Network)
            // The return value is assigned to State, guaranteeing a refresh
            self.image = await coverArtManager.loadAlbumImage(
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
        } else if let _ = coverArtManager.getImageError(for: album.id, size: context.size) {
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
