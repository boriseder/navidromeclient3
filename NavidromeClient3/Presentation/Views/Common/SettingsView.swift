//
//  SettingsView.swift
//  NavidromeClient3
//
//  Swift 6: Restored Detailed Diagnostics
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppInitializer.self) private var appInitializer
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(OfflineManager.self) private var offlineManager
    
    var body: some View {
        NavigationStack {
            List {
                // ... (Existing Sections) ...
                
                // MARK: - Storage Stats (Restored)
                Section(header: Text("Storage & Cache")) {
                    LabeledContent("Downloaded Albums", value: "\(downloadManager.downloadedAlbums.count)")
                    LabeledContent("Cached Images", value: "Calculating...") // Connect to ImageCache
                    
                    // Health Check
                    if !downloadManager.downloadErrors.isEmpty {
                        LabeledContent("Download Errors", value: "\(downloadManager.downloadErrors.count)")
                            .foregroundStyle(.red)
                    }
                    
                    Button("Clear Image Cache", role: .destructive) {
                        // Action
                    }
                    Button("Delete All Downloads", role: .destructive) {
                        downloadManager.downloadedAlbums.removeAll()
                        // trigger file deletion
                    }
                }
                
                // MARK: - Diagnostics (Restored)
                Section(header: Text("Diagnostics")) {
                    LabeledContent("Offline Mode", value: offlineManager.isOfflineMode ? "Active" : "Inactive")
                    LabeledContent("Download Queue", value: "\(downloadManager.activeDownloads.count)")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
