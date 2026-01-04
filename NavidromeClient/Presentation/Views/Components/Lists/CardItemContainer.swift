//
//  CardItemContainer.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - FIXED: Added 'import Observation'
//  - FIXED: Constrained width to prevent text stretching
//

import SwiftUI
import Observation

enum CardContent {
    case album(Album)
    case artist(Artist)
    case playlist // Placeholder
}

struct CardItemContainer: View {
    let content: CardContent
    let index: Int
    
    // Define a fixed card width
    private let cardWidth: CGFloat = 160
    
    @Environment(CoverArtManager.self) var coverArtManager
    @Environment(ThemeManager.self) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.elementGap) {
            imageSection
                .frame(width: cardWidth, height: cardWidth)
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            
            textSection
                .frame(width: cardWidth, alignment: .leading)
        }
        .frame(width: cardWidth)
        .padding(.bottom, DSLayout.elementPadding)
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
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(album.name)
                    .font(DSText.body)
                    .foregroundStyle(theme.textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(album.artist)
                    .font(DSText.detail)
                    .foregroundStyle(theme.textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: cardWidth, alignment: .leading)
        case .artist(let artist):
            Text(artist.name)
                .font(DSText.body)
                .foregroundStyle(theme.textColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .frame(width: cardWidth, alignment: .center)
        case .playlist:
            EmptyView()
        }
    }
}
