//
//  AlbumsViewContent.swift - REAL FIX: Preloading for actual AlbumsView
//  NavidromeClient
//
//   FIXED: Replace .onAppear + preloadWhenIdle with proper lifecycle
//

import SwiftUI

struct AlbumsView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    
    @State private var searchText = ""
    @State private var selectedAlbumSort: ContentService.AlbumSortType = .alphabetical
    @State private var showOnlyDownloaded = false
    @StateObject private var debouncer = Debouncer()
    
    // NEW: Track what we've preloaded
    @State private var lastPreloadedCount = 0
    
    // MARK: - Filter Logic
    
    private var displayedAlbums: [Album] {
        let baseAlbums: [Album]
        
        switch networkMonitor.contentLoadingStrategy {
        case .online:
            baseAlbums = musicLibraryManager.albums
        case .offlineOnly:
            baseAlbums = offlineManager.offlineAlbums
        case .setupRequired:
            baseAlbums = []
        }
        
        let filteredAlbums: [Album]
        if showOnlyDownloaded && networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent {
            let downloadedIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
            filteredAlbums = baseAlbums.filter { downloadedIds.contains($0.id) }
        } else {
            filteredAlbums = baseAlbums
        }
        
        if searchText.isEmpty {
            return filteredAlbums
        } else {
            return filteredAlbums.filter { album in
                album.name.localizedCaseInsensitiveContains(searchText) ||
                album.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
        
    var body: some View {
        NavigationStack {
            ZStack {
                
                if theme.backgroundStyle == .dynamic {
                    DynamicMusicBackground()
                }
                
                contentView
            }
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(
                theme.colorScheme,
                for: .navigationBar
            )
            .searchable(text: $searchText, prompt: "Search albums...")
            .refreshable {
                guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
                await refreshAllData()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            // NEW: Proper lifecycle-aware preloading
            .task(id: displayedAlbums.count) {
                // Only preload if we have MORE albums than last time
                guard displayedAlbums.count > lastPreloadedCount else { return }
                guard displayedAlbums.count > 0 else { return }
                
                // Small delay to let grid render first
                try? await Task.sleep(nanoseconds: 300_000_000)
                
                await preloadVisibleAlbums()
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    
                    // Sort Menu
                    Menu {
                        ForEach(ContentService.AlbumSortType.allCases, id: \.self) { sortType in
                            Button {
                                Task {
                                    await loadAlbums(sortBy: sortType)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: sortType.icon)
                                    Text(sortType.displayName)
                                    Spacer()
                                    if selectedAlbumSort == sortType {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        Divider()
                        Text("Filter")
                            .font(DSText.emphasized)
                            .foregroundColor(.secondary)
                        Button {
                            showOnlyDownloaded = false
                        } label: {
                            HStack {
                                Image(systemName: "music.note.house")
                                Text("All Albums")
                                Spacer()
                                if !showOnlyDownloaded {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        if downloadManager.downloadedAlbums.count > 0 {
                            Button {
                                showOnlyDownloaded = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Downloaded Only (\(downloadManager.downloadedAlbums.count))")
                                    Spacer()
                                    if showOnlyDownloaded {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        Divider()
                        NavigationLink(destination: SettingsView()) {
                            Label("Settings", systemImage: "gear")
                        }


                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSLayout.contentGap) {
                
                LazyVGrid(columns: GridColumns.two, spacing: DSLayout.contentGap) {
                    ForEach(displayedAlbums.indices, id: \.self) { index in
                        let album = displayedAlbums[index]
                        
                        NavigationLink(value: album) {
                            CardItemContainer(content: .album(album), index: index)
                        }
                        .onAppear {
                            // Existing: Load more when nearing end
                            if networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent &&
                               index >= displayedAlbums.count - 5 {
                                Task {
                                    await musicLibraryManager.loadMoreAlbumsIfNeeded()
                                }
                            }
                            
                            // NEW: Progressive preload as user scrolls
                            if index > lastPreloadedCount - 10 && index < displayedAlbums.count - 1 {
                                Task {
                                    await preloadNextBatch(from: index)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, DSLayout.miniPlayerHeight)
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, DSLayout.screenPadding)
    }
    
    // MARK: - Business Logic
    
    private func refreshAllData() async {
        await musicLibraryManager.refreshAllData()
        lastPreloadedCount = 0  // Reset to trigger new preload
    }
    
    private func loadAlbums(sortBy: ContentService.AlbumSortType) async {
        selectedAlbumSort = sortBy
        await musicLibraryManager.loadAlbumsProgressively(sortBy: sortBy, reset: true)
        lastPreloadedCount = 0  // Reset to trigger new preload
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            // Search filtering happens automatically via computed property
        }
    }
    
    // MARK: - NEW: Intelligent Preloading
    
    private func preloadVisibleAlbums() async {
        let albumsToPreload = Array(displayedAlbums.prefix(40))  // Increased from 20
        guard !albumsToPreload.isEmpty else { return }
        
        AppLogger.general.info("🎨 Preloading \(albumsToPreload.count) album covers")
        
        // Use controlled preload with higher priority
        await coverArtManager.preloadAlbumsControlled(
            albumsToPreload,
            context: .card
        )
        
        lastPreloadedCount = displayedAlbums.count
        AppLogger.general.info("✅ Preload completed - cached \(albumsToPreload.count) covers")
    }
    
    private func preloadNextBatch(from index: Int) async {
        let batchStart = index + 1
        let batchEnd = min(batchStart + 20, displayedAlbums.count)
        
        guard batchStart < displayedAlbums.count else { return }
        
        let batch = Array(displayedAlbums[batchStart..<batchEnd])
        
        AppLogger.general.debug("🎨 Preloading scroll batch: \(batch.count) albums from index \(batchStart)")
        
        await coverArtManager.preloadAlbumsControlled(
            batch,
            context: .card
        )
        
        lastPreloadedCount = max(lastPreloadedCount, batchEnd)
    }
}
