//
//  AlbumDetailHeaderView.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Types & Init Calls
//

import SwiftUI

struct AlbumDetailHeaderView: View {
    // FIX: Use simple 'Album' type (removed module prefix)
    let album: Album
    
    var body: some View {
        VStack(spacing: 16) { // DSLayout.contentGap
            // This now matches AlbumImageView.init(album:context:)
            AlbumImageView(album: album, context: .detail)
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12)) // DSCorners.content
                .shadow(radius: 10)
            
            VStack(spacing: 4) { // DSLayout.tightGap
                Text(album.name)
                    .font(.title3) // DSText.fine
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(album.artist)
                    .font(.subheadline) // DSText.detail
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) { // DSLayout.elementGap
                    if let year = album.year {
                        Text(String(year))
                    }
                    if let genre = album.genre {
                        Text("•")
                        Text(genre)
                    }
                }
                .font(.caption) // DSText.metadata
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24) // DSLayout.sectionGap
    }
}
