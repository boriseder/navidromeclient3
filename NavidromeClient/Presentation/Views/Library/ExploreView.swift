//
//  ExploreView.swift - FIXED: All Issues Resolved
//  NavidromeClient
//
//  Swift 6 Compliance with improved skeleton, error handling, and performance
//  - REFACTORED: Bug 10 - Replaced boolean soup with clean ViewState Enum
//

import SwiftUI
import Observation

struct ExploreView: View {
    @Environment(ThemeManager.self) var theme
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(NetworkMonitor.self) var networkMonitor
    @Environment(OfflineManager.self) var offlineManager
    @Environment(DownloadManager.self) var downloadManager
    @Environment(CoverArtManager.self) var coverArtManager
    @Environment(ExploreManager.self) var exploreManager
    @Environment(AppConfig.self) var appConfig
    
    @State private var cachedUsername: String = "User"
    
    private enum ViewState: Equatable {
        case loading
        case online
        case offline
        case empty
    }
    
    private var currentViewState: ViewState {
        let strategy = networkMonitor.contentLoadingStrategy
        
        // Show skeleton if we are online, but haven't finished loading and have no data
        if strategy == .online && !exploreManager.hasCompletedInitialLoad && !exploreManager.hasExploreViewData {
            return .loading
        }
        
        // Otherwise, map directly to the strategy
        switch strategy {
        case .online:
            return .online
        case .offlineOnly:
            return .offline
        case .setupRequired, .initializing:
            return .empty
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
            .task(id: networkMonitor.contentLoadingStrategy) {
                await loadInitialData()
            }
            .task(id: exploreManager.hasExploreViewData) {
                guard exploreManager.hasExploreViewData else { return }
                await preloadVisibleContent()
            }
            .navigationTitle("Explore your music")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(album: album)
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    makeToolbarMenu()
                }
            }
            .refreshable {
                await handleRefresh()
            }
        }
    }
    
    @ViewBuilder
    private func makeToolbarMenu() -> some View {
        Menu {
            if networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent {
                Button {
                    Task { await refreshRandomAlbums() }
                } label: {
                    Label("Refresh random albums", systemImage: "arrow.clockwise")
                }
                Divider()
            }
            NavigationLink(destination: SettingsView()) {
                Label("Settings", systemImage: "person.crop.circle.fill")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSLayout.contentGap) {
                switch currentViewState {
                case .loading:
                    skeletonContent
                        .transition(.opacity)
                case .online:
                    onlineContent
                        .transition(.opacity)
                case .offline:
                    offlineContent
                        .transition(.opacity)
                case .empty:
                    EmptyView()
                        .transition(.opacity)
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, DSLayout.screenPadding)
        .animation(.easeInOut(duration: 0.3), value: currentViewState)
        // Reserve space for mini player above tab bar, only when active
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if playerVM.currentSong != nil {
                Color.clear.frame(height: DSLayout.miniPlayerHeight)
            }
        }
    }
    
    
    // MARK: - Skeleton View
    
    private var skeletonContent: some View {
        LazyVStack(alignment: .leading, spacing: DSLayout.contentGap) {
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 32)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 150, height: 20)
            }
            .padding(.top, DSLayout.sectionGap)
            
            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: DSLayout.elementGap) {
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 150, height: 24)
                        Spacer()
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: DSLayout.contentGap) {
                            ForEach(0..<5, id: \.self) { _ in
                                VStack(alignment: .leading, spacing: 8) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 160, height: 160)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(width: 120, height: 16)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 80, height: 12)
                                }
                            }
                        }
                    }
                }
                .padding(.top, DSLayout.sectionGap)
            }
        }
        .redacted(reason: .placeholder)
        .shimmering()
    }
    
    
    // MARK: - Content
    
    private var onlineContent: some View {
        LazyVStack(spacing: DSLayout.elementGap) {
            /*
            WelcomeHeader(
                username: cachedUsername,
                nowPlaying: playerVM.currentSong
            )
            */
            if !exploreManager.recentAlbums.isEmpty {
                ExploreSection(
                    title: "Recently played",
                    albums: exploreManager.recentAlbums,
                    icon: "clock.fill",
                    accentColor: .orange
                )
            }
            
            if !exploreManager.newestAlbums.isEmpty {
                ExploreSection(
                    title: "Newly added",
                    albums: exploreManager.newestAlbums,
                    icon: "sparkles",
                    accentColor: .green
                )
            }
            
            if !exploreManager.frequentAlbums.isEmpty {
                ExploreSection(
                    title: "Often played",
                    albums: exploreManager.frequentAlbums,
                    icon: "chart.bar.fill",
                    accentColor: .purple
                )
            }
            
            if !exploreManager.randomAlbums.isEmpty {
                ExploreSection(
                    title: "Explore",
                    albums: exploreManager.randomAlbums,
                    icon: "dice.fill",
                    accentColor: .blue,
                    showRefreshButton: true,
                    refreshAction: { await refreshRandomAlbums() }
                )
            }
        }
    }
    
    private var offlineContent: some View {
        LazyVStack(alignment: .leading, spacing: DSLayout.screenGap) {
            OfflineWelcomeHeader(
                downloadedAlbums: downloadManager.downloadedAlbums.count,
                isConnected: networkMonitor.canLoadOnlineContent
            )
            
            if !offlineManager.offlineAlbums.isEmpty {
                ExploreSection(
                    title: "Downloaded Albums",
                    albums: Array(offlineManager.offlineAlbums.prefix(10)),
                    icon: "arrow.down.circle.fill",
                    accentColor: .green
                )
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Business Logic
    
    private func loadInitialData() async {
        // Cache username
        if let username = appConfig.credentials?.username {
            cachedUsername = username
        }
        
        // Load explore data
        await exploreManager.loadExploreData()
    }
    
    private func handleRefresh() async {
        await exploreManager.loadExploreData()
        await preloadVisibleContent()
    }
    
    private func refreshRandomAlbums() async {
        await exploreManager.refreshRandomAlbums()
        await preloadVisibleContent()
    }
    
    private func preloadVisibleContent() async {
        var albumsToPreload: [Album] = []
        albumsToPreload.reserveCapacity(30)
        
        // Take only what we need from each section
        let sections = [
            exploreManager.recentAlbums,
            exploreManager.newestAlbums,
            exploreManager.frequentAlbums,
            exploreManager.randomAlbums
        ]
        
        for section in sections {
            let remaining = 30 - albumsToPreload.count
            guard remaining > 0 else { break }
            albumsToPreload.append(contentsOf: section.prefix(remaining))
        }
        
        guard !albumsToPreload.isEmpty else { return }
        
        await coverArtManager.preloadAlbumsControlled(
            albumsToPreload,
            context: .card
        )
    }
}


// MARK: - ExploreSection

struct ExploreSection: View {
    @Environment(ThemeManager.self) var theme

    let title: String
    let albums: [Album]
    let icon: String
    let accentColor: Color
    var showRefreshButton: Bool = false
    var refreshAction: (() async -> Void)?
    
    @State private var isRefreshing: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Label(title, systemImage: icon)
                    .font(DSText.prominent)
                    .foregroundColor(theme.textColor)

                Spacer()
                
                if showRefreshButton, let refreshAction = refreshAction {
                    Button {
                        Task {
                            // FIX #10: Use defer for proper state cleanup
                            isRefreshing = true
                            defer { isRefreshing = false }
                            await refreshAction()
                        }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                                .padding(.trailing, DSLayout.elementPadding)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(DSText.emphasized)
                                .foregroundColor(theme.textColor)
                                .padding(.trailing, DSLayout.elementPadding)
                        }
                    }
                    .disabled(isRefreshing)
                    .foregroundColor(accentColor)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: DSLayout.contentGap) {
                    ForEach(albums.indices, id: \.self) { index in
                        let album = albums[index]
                        NavigationLink(value: album) {
                            EntityCard(
                                title: album.name,
                                subtitle: album.artist
                            ) {
                                AlbumImageView(album: album, context: .card)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, DSLayout.sectionGap)
    }
}


// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let shimmerWidth = width * 2
            
            content
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            Color.white.opacity(0.3),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: shimmerWidth)
                    .offset(x: phase)
                    .mask(content)
                )
                .onAppear {
                    withAnimation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false)
                    ) {
                        phase = shimmerWidth
                    }
                }
        }
    }
}

extension View {
    @ViewBuilder
    func shimmering(active: Bool = true) -> some View {
        if active {
            self.modifier(ShimmerModifier())
        } else {
            self
        }
    }
}
