import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var theme: ThemeManager

    @State private var searchText = ""
    @StateObject private var debouncer = Debouncer()
    
    @State private var lastPreloadedCount = 0
    
    // MARK: - Unified State Logic
    
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
            // Proper lifecycle-aware preloading
            .task(id: displayedArtists.count) {
                // Only preload if we have MORE artists than last time
                guard displayedArtists.count > lastPreloadedCount else { return }
                guard displayedArtists.count > 0 else { return }
                
                // Small delay to let list render first
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
                        // Progressive preload as user scrolls
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
        lastPreloadedCount = 0  // Reset to trigger new preload
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            // Search filtering happens automatically via computed property
        }
    }
    
    // MARK: - Intelligent Preloading
    
    private func preloadVisibleArtists() async {
        let artistsToPreload = Array(displayedArtists.prefix(40))  // ✅ Increased from 20
        guard !artistsToPreload.isEmpty else { return }
        
        AppLogger.general.info("🎨 Preloading \(artistsToPreload.count) artist images")
        
        // Use controlled preload with higher priority
        await coverArtManager.preloadArtists(
            artistsToPreload,
            context: .artistList
        )
        
        lastPreloadedCount = displayedArtists.count
        AppLogger.general.info("Artist preload completed - cached \(artistsToPreload.count) images")
    }
    
    private func preloadNextBatch(from index: Int) async {
        let batchStart = index + 1
        let batchEnd = min(batchStart + 20, displayedArtists.count)
        
        guard batchStart < displayedArtists.count else { return }
        
        let batch = Array(displayedArtists[batchStart..<batchEnd])
        
        AppLogger.general.debug("🎨 Preloading scroll batch: \(batch.count) artists from index \(batchStart)")
        
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
    
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
            // Artist Image
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
                // Show offline indicator if available offline
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
        OfflineManager.shared.isArtistAvailableOffline(artist.name)
    }
}
