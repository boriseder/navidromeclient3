//
//  ExploreView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Environment(Type.self)
//

import SwiftUI

struct ExploreView: View {
    @Environment(ExploreManager.self) var exploreManager
    @Environment(NetworkMonitor.self) var networkMonitor
    @Environment(ThemeManager.self) var theme
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DSLayout.sectionGap) {
                        if exploreManager.isLoading {
                            ProgressView()
                                .padding()
                        } else if let error = exploreManager.error {
                            ContentUnavailableView("Error loading content", systemImage: "exclamationmark.triangle", description: Text(error))
                        } else {
                            if !exploreManager.recentAlbums.isEmpty {
                                HorizontalAlbumSection(title: "Recently Played", albums: exploreManager.recentAlbums)
                            }
                            
                            if !exploreManager.newestAlbums.isEmpty {
                                HorizontalAlbumSection(title: "Newly Added", albums: exploreManager.newestAlbums)
                            }
                            
                            if !exploreManager.frequentAlbums.isEmpty {
                                HorizontalAlbumSection(title: "Most Played", albums: exploreManager.frequentAlbums)
                            }
                            
                            if !exploreManager.randomAlbums.isEmpty {
                                HorizontalAlbumSection(title: "Random Picks", albums: exploreManager.randomAlbums)
                            }
                        }
                    }
                    .padding(.vertical, DSLayout.contentPadding)
                    .padding(.bottom, DSLayout.miniPlayerHeight)
                }
                .refreshable {
                    await exploreManager.loadExploreData()
                }
            }
            .navigationTitle("Explore")
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
        }
        .task {
            if exploreManager.recentAlbums.isEmpty {
                await exploreManager.loadExploreData()
            }
        }
    }
}

struct HorizontalAlbumSection: View {
    let title: String
    let albums: [Album]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.elementGap) {
            Text(title)
                .font(DSText.sectionTitle)
                .foregroundStyle(DSColor.onLight)
                .padding(.horizontal, DSLayout.screenPadding)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DSLayout.elementGap) {
                    ForEach(albums) { album in
                        NavigationLink(value: album) {
                            CardItemContainer(content: .album(album), index: 0)
                                .frame(width: 140)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, DSLayout.screenPadding)
            }
        }
    }
}
