// ContentView.swift - Navigation direkt zu MainTabView
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var appInitializer: AppInitializer  // ✅ Added
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var theme: ThemeManager
    
    @State private var showingSettings = false
    @State private var isInitialSetup = false
    @State private var serviceInitError: String?
    
    var body: some View {
        Group {
            switch networkMonitor.contentLoadingStrategy {
            case .setupRequired:
                WelcomeView {
                    isInitialSetup = true
                    showingSettings = true
                }
            case .online, .offlineOnly:
                TabView {
                    ExploreView()
                        .tabItem {
                            Image(systemName: "music.note.house")
                            Text("Explore")
                        }
                        .tag(0)
                    
                    AlbumsView()
                        .tabItem {
                            Image(systemName: "record.circle")
                            Text("Albums")
                        }
                        .tag(1)
                    
                    ArtistsView()
                        .tabItem {
                            Image(systemName: "person.2")
                            Text("Artists")
                        }
                        .tag(2)
                    
                    GenreView()
                        .tabItem {
                            Image(systemName: "music.note.list")
                            Text("Genres")
                        }
                        .tag(3)
                    
                    FavoritesView()
                        .tabItem {
                            Image(systemName: "heart")
                            Text("Favorites")
                        }
                        .tag(4)
                }
                .accentColor(theme.accent)
                .id(theme.accent) // zwingt SwiftUI, die TabView neu zu rendern, wenn sich die Farbe ändert
                .overlay(networkStatusOverlay, alignment: .top)
                .overlay(alignment: .bottom) {
                    MiniPlayerView()
                        .environmentObject(playerVM)
                        .padding(.bottom, DSLayout.miniPlayerHeight) // Standard tab bar height
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                ServerEditView(dismissParent: {
                    if isInitialSetup {
                        showingSettings = false
                        isInitialSetup = false
                    }
                })
                .navigationTitle("Server Setup")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    
    private func retryServiceInitialization() async {
        guard let credentials = appConfig.getCredentials() else {
            serviceInitError = "No credentials available"
            return
        }
        
        serviceInitError = nil
        
        // ✅ Updated: No longer posts notification - AppInitializer handles this automatically
        // Just trigger reinit directly
        try? await appInitializer.reinitializeAfterConfiguration()
        
        // Wait for initialization with timeout
        for attempt in 0..<10 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if appInitializer.areServicesReady {  // ✅ Changed from appConfig to appInitializer
                AppLogger.ui.info("Service initialization retry succeeded")
                return
            }
        }
        
        serviceInitError = "Retry failed - check your connection"
    }
    
    // MARK: - Network Status Overlay
    @ViewBuilder
    private var networkStatusOverlay: some View {
        // DISTINGUISH between different offline reasons
        switch networkMonitor.contentLoadingStrategy {
            case .offlineOnly(let reason):
                OfflineReasonBanner(reason: reason)
                    .padding(.horizontal, DSLayout.screenPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(DSAnimations.ease, value: networkMonitor.canLoadOnlineContent)
                
            case .online, .setupRequired:
                EmptyView()
        }
    }
}
