//
//  ExploreView.swift
//  NavidromeClient
//
//  Swift 6: @Environment Migration
//

import SwiftUI

struct ExploreView: View {
    @Environment(ExploreManager.self) private var exploreManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: DSLayout.sectionGap) {
                if exploreManager.isLoading {
                    ProgressView().padding()
                } else {
                    // 1. Recent
                    if !exploreManager.recentAlbums.isEmpty {
                        AlbumRowSection(title: "Recently Played", albums: exploreManager.recentAlbums)
                    }
                    
                    // 2. Newest
                    if !exploreManager.newestAlbums.isEmpty {
                        AlbumRowSection(title: "Newest", albums: exploreManager.newestAlbums)
                    }
                    
                    // 3. Random
                    if !exploreManager.randomAlbums.isEmpty {
                        AlbumRowSection(title: "Random", albums: exploreManager.randomAlbums)
                    }
                }
            }
            .padding(.vertical, DSLayout.screenPadding)
        }
        .navigationTitle("Explore")
        .task {
            await exploreManager.loadExploreData()
        }
        .refreshable {
            await exploreManager.loadExploreData()
        }
    }
}

// Subview helper (simplified)
struct AlbumRowSection: View {
    let title: String
    let albums: [Album]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.elementGap) {
            Text(title)
                .font(DSText.sectionTitle)
                .padding(.horizontal, DSLayout.screenPadding)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSLayout.contentGap) {
                    ForEach(albums) { album in
                        NavigationLink(value: album) {
                            VStack(alignment: .leading) {
                                AlbumImageView(albumId: album.id, size: 150)
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                                
                                Text(album.name)
                                    .font(DSText.emphasized)
                                    .lineLimit(1)
                                Text(album.artist)
                                    .font(DSText.metadata)
                                    .foregroundColor(DSColor.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 150)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DSLayout.screenPadding)
            }
        }
    }
}
