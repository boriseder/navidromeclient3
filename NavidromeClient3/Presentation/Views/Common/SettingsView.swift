//
//  SettingsView.swift - CLEANED: Removed fake metrics and dead code
//  NavidromeClient
//
//   REMOVED: Fake response times, duplicate health indicators
//   REMOVED: Always-zero memory count KPIs
//   IMPROVED: Replaced with useful download statistics
//

import SwiftUI

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var connectionVM: ConnectionViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var appInitializer: AppInitializer
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @Environment(\.dismiss) private var dismiss

    @State private var showingFactoryResetConfirmation = false
    @State private var isPerformingReset = false

    var body: some View {
        NavigationStack {
            List {
                GeneralSettingsSection
                NavidromeSection
                NetworkDebugSection
                if appInitializer.isConfigured {
                    CacheSection
                    ServerDetailsSection
                    DangerZoneSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(appInitializer.isConfigured ? "Settings" : "Initial Setup")
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .disabled(isPerformingReset)
            .overlay { if isPerformingReset { FactoryResetOverlayView() } }
            .confirmationDialog(
                "Logout & Factory Reset",
                isPresented: $showingFactoryResetConfirmation
            ) {
                Button("Reset App", role: .destructive) {
                    Task { await performFactoryReset() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete ALL data including downloads, server settings and cache.")
            }
        }
    }

    // MARK: - Sections

    private var NavidromeSection: some View {
        Section {
            if let creds = AppConfig.shared.getCredentials() {
                SettingsRow(title: "Server:", value: creds.baseURL.absoluteString)
                SettingsRow(title: "User:", value: creds.username)
            }
            NavigationLink(destination: ServerEditView()) {
                Text("Edit Server")
            }
        } header: {
            Text("Navidrome Server Settings")
        } footer: {
            Text("Your (self-)hosted Navidrome server. Don't forget to add port (usually 4533).")
        }
        .task { await connectionVM.testConnection() }
    }

    private var CacheSection: some View {
        Section {
            NavigationLink("Cache Settings") { CacheSettingsView() }
            SettingsRow(title: "Cover Art Cache", value: PersistentImageCache.shared.getCacheStats().diskSizeFormatted)
            SettingsRow(title: "Download Cache", value: downloadManager.totalDownloadSize())
        } header: {
            Text("Cache & Downloads")
        }
    }

    private var GeneralSettingsSection: some View {
        Group {
            Section(header: Text("Debug")) {
                NavigationLink(destination: CoverArtDebugView()) {
                    Label("Cover Art Debug", systemImage: "photo.artframe")
                }
                
            }
            Section(header: Text("Appearance")) {
                Picker("Select Theme", selection: $theme.backgroundStyle) {
                    ForEach(UserBackgroundStyle.allCases, id: \.self) { option in
                        Text(option.rawValue.capitalized).tag(option)
                    }
                }
                .pickerStyle(.menu)
                
                HStack {
                    Text("Accent Color")
                    Spacer()
                    Menu {
                        ForEach(UserAccentColor.allCases) { colorOption in
                            Button {
                                theme.accentColor = colorOption
                            } label: {
                                Label(colorOption.rawValue.capitalized, systemImage: "circle.fill")
                                if theme.accentColor == colorOption {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .tint(colorOption.color)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(theme.accent)
                            Text(theme.accentColor.rawValue.capitalized)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var ServerDetailsSection: some View {
        Section {
            SettingsRow(
                title: "Connection:",
                value: connectionVM.isConnected ?
                    "Connected via \(networkMonitor.currentConnectionType.displayName)" :
                    networkMonitor.connectionStatusDescription
            )
        } header: {
            Text("Server Info")
        }
        .task { await connectionVM.testConnection() }
    }

    private var DangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showingFactoryResetConfirmation = true
            } label: {
                Label("Logout & Factory Reset", systemImage: "exclamationmark.triangle.fill")
            }
            .disabled(isPerformingReset)
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("This will reset the app to its initial state. All local data will be lost.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var NetworkDebugSection: some View {
        Section {
            NetworkDebugBanner()
        } header: {
            Text("Network Debug")
        } footer: { }
    }
    
    // MARK: - Actions
    private func performFactoryReset() async {
        isPerformingReset = true
        defer { isPerformingReset = false }
        
        await appInitializer.performFactoryReset()
        
        await MainActor.run {
            songManager.reset()
        }
        
        await MainActor.run { dismiss() }
    }
}

// MARK: - Helper Components

struct SettingsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Factory Reset

struct FactoryResetOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("Factory Reset in Progress...").foregroundStyle(.white)
                Text("Clearing all data and resetting app").foregroundStyle(.white.opacity(0.8))
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - CacheSettingsView
struct CacheSettingsView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager

    @State private var cacheStats = PersistentImageCache.shared.getCacheStats()
    @State private var showingClearConfirmation = false
    @State private var showingClearSuccess = false

    var body: some View {
        List {
            Section("Cover Art Cache") {
                CacheStatsRow(title: "Cached Images", value: "\(cacheStats.diskCount)", icon: "photo.stack")
                CacheStatsRow(title: "Cache Size", value: cacheStats.diskSizeFormatted, icon: "internaldrive")
                CacheStatsRow(title: "Usage", value: String(format: "%.1f%%", cacheStats.usagePercentage), icon: "chart.pie")

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("Clear Cover Art Cache", systemImage: "trash")
                }
            }

            Section("Downloaded Music") {
                CacheStatsRow(
                    title: "Downloaded Albums",
                    value: "\(downloadManager.downloadedAlbums.count)",
                    icon: "arrow.down.circle.fill"
                )
                CacheStatsRow(
                    title: "Total Size",
                    value: downloadManager.totalDownloadSize(),
                    icon: "internaldrive"
                )
                CacheStatsRow(
                    title: "Songs Available Offline",
                    value: "\(downloadManager.downloadedAlbums.reduce(0) { $0 + $1.songs.count })",
                    icon: "music.note"
                )
                
                Button(role: .destructive) {
                    downloadManager.deleteAllDownloads()
                } label: {
                    Label("Delete ALL Music", systemImage: "trash")
                }
            }
            
            Section {
                Button("Clear Memory Cache") {
                    coverArtManager.clearMemoryCache()
                    updateCacheStats()
                }
            } header: {
                Text("Memory Management")
            } footer: {
                Text("Clears in-memory cached images. They will be reloaded from disk or network as needed.")
                    .font(.caption)
            }
        }
        .navigationTitle("Cache Management")
        .confirmationDialog("Clear Cover Art Cache?", isPresented: $showingClearConfirmation) {
            Button("Clear Cache", role: .destructive) { clearCoverArtCache() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all cached cover art images.")
        }
        .alert("Cache Cleared", isPresented: $showingClearSuccess) {
            Button("OK") {}
        } message: {
            Text("Cover art cache has been successfully cleared.")
        }
        .task { updateCacheStats() }
        .refreshable { updateCacheStats() }
    }

    private func updateCacheStats() {
        cacheStats = PersistentImageCache.shared.getCacheStats()
    }
    
    private func clearCoverArtCache() {
        PersistentImageCache.shared.clearCache()
        coverArtManager.clearMemoryCache()
        updateCacheStats()
        showingClearSuccess = true
    }
}

struct CacheStatsRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon).frame(width: 20)
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
