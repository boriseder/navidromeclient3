//
//  CacheSettingsView.swift
//  NavidromeClient
//
//  Created by EDER Boris (ICS480-ECC) on 08.05.26.
//


//
//  CacheSettingsView.swift
//  NavidromeClient
//

import SwiftUI
import Observation

struct CacheSettingsView: View {
    @Environment(DownloadManager.self) var downloadManager
    @Environment(CoverArtManager.self) var coverArtManager

    @State private var cacheStats = PersistentImageCache.CacheStats(
        memoryCount: 0,
        diskCount: 0,
        diskSize: 0,
        maxSize: 1
    )
    @State private var showingClearCoverArtConfirmation = false
    @State private var showingDeleteMusicConfirmation = false
    @State private var showingClearSuccess = false

    var body: some View {
        List {
            Section("Cover Art Cache") {
                CacheStatsRow(title: "Cached Images", value: "\(cacheStats.diskCount)", icon: "photo.stack")
                CacheStatsRow(title: "Cache Size", value: cacheStats.diskSizeFormatted, icon: "internaldrive")
                CacheStatsRow(title: "Usage", value: String(format: "%.1f%%", cacheStats.usagePercentage), icon: "chart.pie")

                Button("Clear Memory Cache") {
                    coverArtManager.clearMemoryCache()
                    Task { await updateCacheStats() }
                }

                Button(role: .destructive) {
                    showingClearCoverArtConfirmation = true
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
                    showingDeleteMusicConfirmation = true
                } label: {
                    Label("Delete All Downloaded Music", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Cache Management")
        .task { await updateCacheStats() }
        .refreshable { await updateCacheStats() }
        .confirmationDialog("Clear Cover Art Cache?", isPresented: $showingClearCoverArtConfirmation) {
            Button("Clear Cache", role: .destructive) {
                Task { await clearCoverArtCache() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all cached cover art images. They will reload from the server.")
        }
        .confirmationDialog("Delete All Music?", isPresented: $showingDeleteMusicConfirmation) {
            Button("Delete All", role: .destructive) {
                downloadManager.deleteAllDownloads()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all downloaded music. You'll need an internet connection to play it again.")
        }
        .alert("Cache Cleared", isPresented: $showingClearSuccess) {
            Button("OK") {}
        } message: {
            Text("Cover art cache has been successfully cleared.")
        }
    }

    private func updateCacheStats() async {
        cacheStats = await PersistentImageCache.shared.getCacheStats()
    }

    private func clearCoverArtCache() async {
        await PersistentImageCache.shared.clearCache()
        coverArtManager.clearMemoryCache()
        await updateCacheStats()
        showingClearSuccess = true
    }
}