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

struct CardItemContainer<Content: View>: View {
    let title: String
    let subtitle: String?
    let imageContext: ImageContext
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DSText.body)
                    .lineLimit(1)
                    .foregroundColor(DSColor.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DSText.metadata)
                        .lineLimit(1)
                        .foregroundColor(DSColor.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

// FIX: AnyShape closure must be Sendable
struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path

    init<S: Shape>(_ wrapped: S) {
        _path = { rect in
            let path = wrapped.path(in: rect)
            return path
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

