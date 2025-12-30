//
//  CardItemContainer.swift
//  NavidromeClient
//
//  REFACTORED: Context-aware image display
//

import SwiftUI

enum CardContent {
    case album(Album)
    case artist(Artist)
    case genre(Genre)
}

struct CardItemContainer: View {
    let content: CardContent
    let index: Int
    
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading) {
            imageView
                .scaledToFill()
                .frame(width: DSLayout.cardCoverNoPadding, height: DSLayout.cardCoverNoPadding)
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
               // .padding(DSLayout.elementPadding)
                        
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(content.title)
                    .font(DSText.metadata)
                    .fontWeight(.bold)
                    .foregroundColor(theme.textColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(content.subtitle)
                    .font(DSText.fine)
                    .foregroundColor(theme.textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    /*
                     
                    Spacer()

                    if let year = content.year {
                        Text(year)
                            .font(DSText.fine)
                            .foregroundColor(appConfig.userBackgroundStyle.dynamicTextColor)
                    } else {
                        Text("").hidden()
                    }
                     */
            }
            .frame(maxWidth: DSLayout.cardCoverNoPadding, alignment: .leading)
            .padding(.horizontal, DSLayout.tightPadding)

        }
        /*
        .background(DSMaterial.background)
        .overlay(
            RoundedRectangle(cornerRadius: DSCorners.tight)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
         */
        .cornerRadius(DSCorners.element)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(content.title), \(content.subtitle), \(content.year ?? "")")
    }
    
    @ViewBuilder
    private var imageView: some View {
        switch content {
        case .album(let album):
            AlbumImageView(album: album, context: .card)
        case .artist(let artist):
            ArtistImageView(artist: artist, context: .artistCard)
        case .genre:
            staticGenreIcon
        }
    }
    
    @ViewBuilder
    private var staticGenreIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DSCorners.tight)
                .fill(LinearGradient(
                    colors: [DSColor.accent.opacity(0.3), DSColor.accent.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Image(systemName: "music.note.list")
                .font(.system(size: DSLayout.largeIcon))
                .foregroundColor(DSColor.primary.opacity(0.7))
        }
        .frame(width: DSLayout.cardCover, height: DSLayout.cardCover)
        .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
    }
}

// MARK: - Extension to CardContent
// This extension handles the presentation logic based on the enum type
extension CardContent {
    var id: String {
        switch self {
        case .album(let album): return album.id
        case .artist(let artist): return artist.id
        case .genre(let genre): return genre.id
        }
    }
    
    var title: String {
        switch self {
        case .album(let album): return album.name
        case .artist(let artist): return artist.name
        case .genre(let genre): return genre.value
        }
    }
    
    var year: String? {
        switch self {
        case .album(let album):
            return album.year.map { String($0) }
        case .artist, .genre:
            return nil
        }
    }
    
    var subtitle: String {
        switch self {
        case .album(let album): return album.artist
        case .artist(let artist):
            guard let count = artist.albumCount else { return "" }
            return "\(count) Album\(count != 1 ? "s" : "")"
        case .genre(let genre):
            let count = genre.albumCount
            return "\(count) Album\(count != 1 ? "s" : "")"
        }
    }
    
    var iconName: String {
        switch self {
        case .album: return "music.note"
        case .artist: return "music.mic"
        case .genre: return "music.note"
        }
    }
    
    var hasChevron: Bool {
        switch self {
        case .album: return false
        default: return true
        }
    }
    
    var clipShape: some Shape {
        switch self {
        case .artist: return AnyShape(Circle())
        default: return AnyShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // A simple helper to allow different shapes for clipShape
    private struct AnyShape: Shape {
        private let closure: (CGRect) -> Path

        init<S: Shape>(_ shape: S) {
            closure = { rect in
                shape.path(in: rect)
            }
        }

        func path(in rect: CGRect) -> Path {
            closure(rect)
        }
    }
}
