//
//  SettingsView.swift
//  NavidromeClient3
//
//  Swift 6: @Bindable for Two-Way Bindings
//

import SwiftUI

struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(ConnectionViewModel.self) private var connectionVM
    @Environment(AppConfig.self) private var appConfig
    
    var body: some View {
        // 1. Create Bindable proxies for objects we need to mutate
        @Bindable var bThemeManager = themeManager
        @Bindable var bConnectionVM = connectionVM
        
        Form {
            Section("Appearance") {
                // 2. Use $ on the bindable proxy
                Picker("Theme", selection: $bThemeManager.backgroundStyle) {
                    Text("Dynamic").tag(UserBackgroundStyle.dynamic)
                    Text("Light").tag(UserBackgroundStyle.light)
                    Text("Dark").tag(UserBackgroundStyle.dark)
                }
                
                ColorPicker("Accent Color", selection: Binding(
                    get: { themeManager.accentColor.color },
                    set: { _ in } // Simplified for example, normally maps back to enum
                ))
            }
            
            Section("Network") {
                // NetworkMonitor usually doesn't have simple bindable properties
                // It uses methods, so we use Buttons/Toggles with custom bindings
                Toggle("Offline Mode", isOn: Binding(
                    get: { !networkMonitor.shouldLoadOnlineContent },
                    set: { wantsOffline in
                        networkMonitor.setManualOfflineMode(wantsOffline)
                    }
                ))
                
                if let status = networkMonitor.state.contentLoadingStrategy.displayName {
                    LabeledContent("Status", value: status)
                }
            }
            
            Section("Server") {
                LabeledContent("URL", value: connectionVM.host)
                LabeledContent("User", value: connectionVM.username)
                
                Button("Logout", role: .destructive) {
                    Task { await appConfig.logout() }
                }
            }
        }
        .navigationTitle("Settings")
    }
}
