//
//  ArtistsView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Compliance & Phase 3.1 Refactoring (ListLayoutWrapper + EntityRow)
//

import SwiftUI
import Observation

struct ArtistsView: View {
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(CoverArtManager.self) var coverArtManager
    @Environment(MusicLibraryManager.self) var musicLibraryManager
    @Environment(NetworkMonitor.self) var networkMonitor
    @Environment(OfflineManager.self) var offlineManager
    @Environment(DownloadManager.self) var downloadManager
    @Environment(ThemeManager.self) var theme

    @State private var searchText = ""
    @State private var debouncer = Debouncer()
    @State private var lastPreloadedCount = 0
    
    private var displayedArtists: [Artist] {
        let artists: [Artist]
        
        switch networkMonitor.contentLoadingStrategy {
        case .online:
            artists = filterArtists(musicLibraryManager.artists)
            
        case .offlineOnly:
            artists = filterArtists(offlineManager.offlineArtists)
            
        case .setupRequired, .initializing:
            artists = []
        }
        
        return artists
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if theme.backgroundStyle == .dynamic {
                    DynamicMusicBackground()
                }
                
                contentView
            }
            .navigationTitle("Artists")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Artist.self) { artist in
                AlbumCollectionView(context: .byArtist(artist))
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(album: album)
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search artists...")
            .refreshable {
                guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
                await refreshAllData()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .task(id: displayedArtists.count) {
                guard displayedArtists.count > lastPreloadedCount else { return }
                guard displayedArtists.count > 0 else { return }
                
                try? await Task.sleep(nanoseconds: 300_000_000)
                await preloadVisibleArtists()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(theme.textColor)
                    }
                }
            }
        }
    }
    
    // MARK: - Refactored Content View mit ListLayoutWrapper
    @ViewBuilder
    private var contentView: some View {
        ListLayoutWrapper {
            ForEach(Array(displayedArtists.enumerated()), id: \.element.id) { index, artist in
                NavigationLink(value: artist) {
                    ArtistListRow(artist: artist)
                }
                .buttonStyle(.plain)
                .onAppear {
                    if index > lastPreloadedCount - 10 && index < displayedArtists.count - 1 {
                        Task {
                            await preloadNextBatch(from: index)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Business Logic
    
    private func filterArtists(_ artists: [Artist]) -> [Artist] {
        let filteredArtists: [Artist]
        
        if searchText.isEmpty {
            filteredArtists = artists
        } else {
            filteredArtists = artists.filter { artist in
                artist.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filteredArtists.sorted(by: { $0.name < $1.name })
    }

    private func refreshAllData() async {
        await musicLibraryManager.refreshAllData()
        lastPreloadedCount = 0
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            // Search filtering happens automatically via computed property
        }
    }
    
    // MARK: - Intelligent Preloading
    
    private func preloadVisibleArtists() async {
        let artistsToPreload = Array(displayedArtists.prefix(40))
        guard !artistsToPreload.isEmpty else { return }
        
        await coverArtManager.preloadArtists(
            artistsToPreload,
            context: .artistList
        )
        
        lastPreloadedCount = displayedArtists.count
    }
    
    private func preloadNextBatch(from index: Int) async {
        let batchStart = index + 1
        let batchEnd = min(batchStart + 20, displayedArtists.count)
        
        guard batchStart < displayedArtists.count else { return }
        
        let batch = Array(displayedArtists[batchStart..<batchEnd])
        
        await coverArtManager.preloadArtists(
            batch,
            context: .artistList
        )
        
        lastPreloadedCount = max(lastPreloadedCount, batchEnd)
    }
}

// MARK: - Refactored Artist Row (Nutzt die generische EntityRow)

struct ArtistListRow: View {
    let artist: Artist
    
    @Environment(OfflineManager.self) var offlineManager

    var body: some View {
        let count = artist.albumCount ?? 0
        let isAvailableOffline = offlineManager.isArtistAvailableOffline(artist.name)
        
        EntityRow(
            title: artist.name,
            leading: {
                ArtistImageView(artist: artist, context: .artistList)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.black.opacity(0.2), lineWidth: 1))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            },
            trailing: {
                if count > 0 {
                    HStack(spacing: DSLayout.tightGap) {
                        Image(systemName: isAvailableOffline ? "arrow.down.circle.fill" : "record.circle")
                            .font(DSText.fine)
                        Text("\(count) Album\(count != 1 ? "s" : "")")
                            .font(DSText.fine)
                    }
                    .foregroundStyle(DSColor.onDark)
                }
            }
        )
    }
}
