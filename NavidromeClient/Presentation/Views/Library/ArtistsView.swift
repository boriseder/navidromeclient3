//
//  ArtistsView.swift - RESTORED: Full Swift 5 Functionality
//  NavidromeClient
//
//  Swift 6 Compliance with ALL original features restored
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
        case .setupRequired:
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
                        Image(systemName: "person.crop.circle.fill")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(displayedArtists.indices, id: \.self) { index in
                    let artist = displayedArtists[index]
                    
                    NavigationLink(value: artist) {
                        ArtistRowView(artist: artist)
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
            .padding(.bottom, DSLayout.miniPlayerHeight)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, DSLayout.screenPadding)
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

// MARK: - Artist Row View

struct ArtistRowView: View {
    let artist: Artist
    
    @Environment(CoverArtManager.self) var coverArtManager
    @Environment(ThemeManager.self) var theme
    @Environment(OfflineManager.self) var offlineManager

    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
            ArtistImageView(artist: artist, context: .artistList)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(.black.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .padding(.vertical, DSLayout.tightPadding)
                .padding(.leading, DSLayout.tightPadding)
            
            Text(artist.name)
                .font(DSText.emphasized)
                .foregroundStyle(DSColor.onDark)
                .lineLimit(1)
        
            Spacer()
            
            if let count = artist.albumCount {
                if isAvailableOffline {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(DSText.fine)
                        .foregroundStyle(DSColor.onDark)
                } else {
                    Image(systemName: "record.circle")
                        .font(DSText.fine)
                        .foregroundStyle(DSColor.onDark)
                }
                
                Text("\(count) Album\(count != 1 ? "s" : "")")
                    .font(DSText.fine)
                    .foregroundStyle(DSColor.onDark)
                    .padding(.trailing, DSLayout.contentPadding)
            }
        }
        .background(theme.backgroundContrastColor.opacity(0.12))
    }
    
    private var isAvailableOffline: Bool {
        offlineManager.isArtistAvailableOffline(artist.name)
    }
}
