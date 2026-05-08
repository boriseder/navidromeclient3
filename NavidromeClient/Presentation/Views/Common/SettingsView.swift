//
//  SettingsView.swift
//  NavidromeClient
//

import SwiftUI
import Observation

struct SettingsView: View {

    @Environment(AppConfig.self) var appConfig
    @Environment(AppInitializer.self) var appInitializer
    @Environment(ThemeManager.self) var theme
    @Environment(ConnectionViewModel.self) var connectionVM
    @Environment(SongManager.self) var songManager
    @Environment(DownloadManager.self) var downloadManager
    @Environment(CoverArtManager.self) var coverArtManager
    @Environment(NetworkMonitor.self) var networkMonitor
    @Environment(\.dismiss) private var dismiss

    @State private var showingFactoryResetConfirmation = false
    @State private var isPerformingReset = false
    @State private var coverArtCacheSize: String = "—"

    var body: some View {
        // @Bindable must be declared at the top of body, not inside a section
        @Bindable var bindableTheme = theme

        List {
            // 1. Appearance — most frequently changed
            AppearanceSection(backgroundStyle: $bindableTheme.backgroundStyle)

            // 2. Server — primary configuration
            ServerSection()

            // 3. Cache — informational + navigation
            if appInitializer.isConfigured {
                CacheOverviewSection(coverArtCacheSize: coverArtCacheSize)
            }

            // 4. Debug — hidden at the bottom where it belongs
            DebugSection()

            // 5. Danger Zone — always last
            if appInitializer.isConfigured {
                DangerZoneSection(
                    isPerformingReset: isPerformingReset,
                    onReset: { showingFactoryResetConfirmation = true }
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(appInitializer.isConfigured ? "Settings" : "Initial Setup")
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .disabled(isPerformingReset)
        .overlay {
            if isPerformingReset { FactoryResetOverlayView() }
        }
        .task {
            let stats = await PersistentImageCache.shared.getCacheStats()
            coverArtCacheSize = stats.diskSizeFormatted
        }
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

    private func performFactoryReset() async {
        isPerformingReset = true
        defer { isPerformingReset = false }
        await appInitializer.performFactoryReset()
        songManager.reset()
        dismiss()
    }
}
