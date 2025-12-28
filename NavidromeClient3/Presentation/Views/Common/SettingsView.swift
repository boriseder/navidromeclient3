//
//  SettingsView.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Type Checking & Theme Enum
//

import SwiftUI
import Observation

// Helper for display names
extension UserBackgroundStyle {
    var displayName: String {
        switch self {
        case .dynamic: return "System Default"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

// Helper for accent names
extension UserAccentColor {
    var displayName: String {
        rawValue.capitalized
    }
}

struct SettingsView: View {
    @Environment(AppInitializer.self) private var appInitializer
    @Environment(ConnectionViewModel.self) private var connectionVM
    @Environment(ThemeManager.self) private var themeManager
    @Environment(OfflineManager.self) private var offlineManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingLogoutConfirmation = false
    @State private var showingResetConfirmation = false
    
    var serverUrl: String? {
        AppConfig.shared.getCredentials()?.baseURL.absoluteString
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Server Section
                Section(header: Text("Server")) {
                    if let url = serverUrl {
                        HStack {
                            Text("URL")
                            Spacer()
                            Text(url)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    
                    Button(role: .destructive) {
                        showingLogoutConfirmation = true
                    } label: {
                        Text("Logout")
                    }
                }
                
                // MARK: - Appearance Section
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: Bindable(themeManager).backgroundStyle) {
                        ForEach(UserBackgroundStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    
                    Picker("Accent Color", selection: Bindable(themeManager).accentColor) {
                        ForEach(UserAccentColor.allCases) { accent in
                            Text(accent.displayName)
                                .foregroundColor(accent.color)
                                .tag(accent)
                        }
                    }
                }
                
                // MARK: - Cache Section
                Section(header: Text("Cache & Storage")) {
                    Button("Clear Image Cache") {
                        Task {
                            await PersistentImageCache.shared.clearCache()
                            CoverArtManager.shared.clearMemoryCache()
                        }
                    }
                    
                    if offlineManager.isOfflineMode {
                        Text("Currently in Offline Mode")
                            .foregroundColor(.orange)
                    }
                }
                
                // MARK: - Danger Zone
                Section(header: Text("Danger Zone")) {
                    Button("Factory Reset App", role: .destructive) {
                        showingResetConfirmation = true
                    }
                }
                
                Section(footer: Text("NavidromeClient3 v1.0")) {
                    // Footer
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Logout", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    Task {
                        AppConfig.shared.clearCredentials()
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to logout? Downloaded content will remain.")
            }
            .alert("Factory Reset", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset Everything", role: .destructive) {
                    Task {
                        await appInitializer.performFactoryReset()
                        dismiss()
                    }
                }
            } message: {
                Text("This will remove all accounts, downloads, and settings. This action cannot be undone.")
            }
        }
    }
}
