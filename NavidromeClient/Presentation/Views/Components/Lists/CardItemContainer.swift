//
//  CardItemContainer.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Environment(Type.self)
//

import SwiftUI

enum CardContent {
    case album(Album)
    case artist(Artist)
    case playlist // Placeholder
}

struct CardItemContainer: View {
    let content: CardContent
    let index: Int
    
    @Environment(CoverArtManager.self) var coverArtManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            imageSection
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            
            textSection
        }
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var imageSection: some View {
        switch content {
        case .album(let album):
            AlbumImageView(album: album, context: .card)
        case .artist(let artist):
            ArtistImageView(artist: artist, context: .artistCard)
        case .playlist:
            Color.gray // Placeholder
        }
    }
    
    @ViewBuilder
    private var textSection: some View {
        switch content {
        case .album(let album):
            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(DSText.body)
                    .foregroundStyle(DSColor.onLight)
                    .lineLimit(1)
                
                Text(album.artist)
                    .font(DSText.metadata)
                    .foregroundStyle(DSColor.secondary)
                    .lineLimit(1)
            }
        case .artist(let artist):
            Text(artist.name)
                .font(DSText.body)
                .foregroundStyle(DSColor.onLight)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        case .playlist:
            EmptyView()
        }
    }
}
