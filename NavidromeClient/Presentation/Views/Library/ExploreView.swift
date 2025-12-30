//
//  ExploreViewContent.swift - FIXED: Preloading triggers after data loads
//  NavidromeClient
//

import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var exploreManager: ExploreManager
    
    @State private var hasAttemptedInitialLoad = false
    @State private var hasPreloaded = false  // NEW: Track if preload happened
    
    private var hasOnlineContent: Bool {
        exploreManager.hasExploreViewData
    }

    private var hasOfflineContent: Bool {
        !offlineManager.offlineAlbums.isEmpty
    }
    
    private var shouldShowSkeleton: Bool {
        !exploreManager.hasCompletedInitialLoad && !hasOnlineContent
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if theme.backgroundStyle == .dynamic {
                    DynamicMusicBackground()
                }
                contentView
            }
            .task {
                guard !hasAttemptedInitialLoad else { return }
                hasAttemptedInitialLoad = true
                
                try? await Task.sleep(nanoseconds: 300_000_000)
                await setupHomeScreenData()
            }
            // Separate task that triggers AFTER data is loaded
            .task(id: hasOnlineContent) {
                guard hasOnlineContent, !hasPreloaded else { return }
                
                // Wait a bit to let UI settle
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                await preloadVisibleContent()
                hasPreloaded = true
            }
            .navigationTitle("Explore & listen")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
            }
            .refreshable {
                await exploreManager.loadExploreData()
                hasPreloaded = false  // Reset to allow new preload
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSLayout.contentGap) {
                if shouldShowSkeleton {
                    skeletonContent
                        .transition(.opacity)
                } else {
                    switch networkMonitor.contentLoadingStrategy {
                    case .online:
                        onlineContent
                            .transition(.opacity)
                    case .offlineOnly:
                        offlineContent
                            .transition(.opacity)
                    case .setupRequired:
                        EmptyView()
                    }
                }
            }
            .padding(.bottom, DSLayout.miniPlayerHeight)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, DSLayout.screenPadding)
        .animation(.easeInOut(duration: 0.3), value: shouldShowSkeleton)
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

    private var onlineContent: some View {
        LazyVStack(spacing: DSLayout.elementGap) {
            WelcomeHeader(
                username: appConfig.getCredentials()?.username ?? "User",
                nowPlaying: playerVM.currentSong
            )
            
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
            }
        }
    }
    
    // MARK: - Business Logic
    
    private func setupHomeScreenData() async {
        await exploreManager.loadExploreData()
    }
    
    private func refreshRandomAlbums() async {
        await exploreManager.refreshRandomAlbums()
        await preloadVisibleContent()
    }
    
    // NEW: Intelligent preloading after data is available
    private func preloadVisibleContent() async {
        let allAlbums = exploreManager.recentAlbums +
                       exploreManager.newestAlbums +
                       exploreManager.frequentAlbums +
                       exploreManager.randomAlbums
        
        guard !allAlbums.isEmpty else { return }
        
        AppLogger.general.info("🎨 Starting controlled preload for \(allAlbums.count) albums")
        
        // Use controlled preload with higher priority
        await coverArtManager.preloadAlbumsControlled(
            Array(allAlbums.prefix(30)),  // Increased from 20
            context: .card
        )
        
        AppLogger.general.info("✅ Preload completed")
    }
}

// MARK: - ExploreSection (unchanged)

struct ExploreSection: View {
    @EnvironmentObject var theme: ThemeManager

    let title: String
    let albums: [Album]
    let icon: String
    let accentColor: Color
    var showRefreshButton: Bool = false
    var refreshAction: (() async -> Void)? = nil
    
    @State private var isRefreshing = false
    
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
                            isRefreshing = true
                            await refreshAction()
                            isRefreshing = false
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
                } else {
                    Image(systemName: "arrow.right")
                        .font(DSText.emphasized)
                        .foregroundColor(theme.textColor)
                        .padding(.trailing, DSLayout.elementPadding)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: DSLayout.contentGap) {
                    ForEach(albums.indices, id: \.self) { index in
                        let album = albums[index]
                        NavigationLink(value: album) {
                            CardItemContainer(content: .album(album), index: index)
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

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
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
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 400
                }
            }
    }
}
