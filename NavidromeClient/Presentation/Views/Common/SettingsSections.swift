//
//  AppearanceSection.swift
//  NavidromeClient
//
//  Created by EDER Boris (ICS480-ECC) on 08.05.26.
//


//
//  SettingsSections.swift
//  NavidromeClient
//
//  Each section is a self-contained View struct.
//  Sections own their own environment access where needed.
//

import SwiftUI
import Observation

// MARK: - AppearanceSection

struct AppearanceSection: View {
    @Environment(ThemeManager.self) var theme
    @Binding var backgroundStyle: UserBackgroundStyle  // ← no change needed here

    var body: some View {
        Section {
            Picker("Background Style", selection: $backgroundStyle) {
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
                            HStack {
                                Label(
                                    colorOption.rawValue.capitalized,
                                    systemImage: "circle.fill"
                                )
                                if theme.accentColor == colorOption {
                                    Image(systemName: "checkmark")
                                }
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
        } header: {
            Text("Appearance")
        }
    }
}

// MARK: - ServerSection

struct ServerSection: View {
    @Environment(AppConfig.self) var appConfig
    @Environment(AppInitializer.self) var appInitializer
    @Environment(ConnectionViewModel.self) var connectionVM
    @Environment(NetworkMonitor.self) var networkMonitor

    var body: some View {
        Section {
            if let creds = appConfig.credentials {
                SettingsRow(title: "Server", value: creds.baseURL.absoluteString)
                SettingsRow(title: "User", value: creds.username)
                SettingsRow(
                    title: "Connection",
                    value: connectionVM.isConnected
                        ? "Connected via \(networkMonitor.currentConnectionType.displayName)"
                        : networkMonitor.connectionStatusDescription
                )
                // Visual status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(connectionVM.isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(connectionVM.isConnected ? "Online" : "Offline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            NavigationLink(destination: ServerEditView()) {
                Text(appInitializer.isConfigured ? "Edit Server" : "Set Up Server")
            }
        } header: {
            Text("Navidrome Server")
        } footer: {
            Text("Your self-hosted Navidrome server. Include the port if needed (usually :4533).")
        }
    }
}

// MARK: - CacheOverviewSection

struct CacheOverviewSection: View {
    @Environment(DownloadManager.self) var downloadManager
    let coverArtCacheSize: String

    var body: some View {
        Section {
            SettingsRow(title: "Cover Art Cache", value: coverArtCacheSize)
            SettingsRow(title: "Downloaded Music", value: downloadManager.totalDownloadSize())
            NavigationLink("Manage Cache") { CacheSettingsView() }
        } header: {
            Text("Cache & Downloads")
        }
    }
}

// MARK: - DebugSection

struct DebugSection: View {
    var body: some View {
        Section {
            NavigationLink(destination: CoverArtDebugView()) {
                Label("Cover Art Debug", systemImage: "photo")
            }
            NavigationLink(destination: NetworkDebugView()) {
                Label("Network Debug", systemImage: "network")
            }
            NavigationLink(destination: DesignSystemGallery()) {
                Label("Design System Gallery", systemImage: "paintpalette")
            }
        } header: {
            Text("Developer")
        }
    }
}

// MARK: - DangerZoneSection

struct DangerZoneSection: View {
    let isPerformingReset: Bool
    let onReset: () -> Void

    var body: some View {
        Section {
            Button(role: .destructive) {
                onReset()
            } label: {
                Label("Logout & Factory Reset", systemImage: "exclamationmark.triangle.fill")
            }
            .disabled(isPerformingReset)
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("Resets the app to its initial state. All local data, downloads and settings will be lost.")
        }
    }
}
