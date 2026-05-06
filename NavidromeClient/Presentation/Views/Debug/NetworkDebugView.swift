//
//  NetworkDebugBanner.swift
//  NavidromeClient
//
//  UPDATED: Settings UI Style
//

import SwiftUI

struct NetworkDebugView: View {
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(OfflineManager.self) private var offlineManager
    @Environment(ConnectionViewModel.self) private var connectionManager
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        List {
            // MARK: - Network Status Section
            Section {
                HStack {
                    Image(systemName: networkMonitor.state.contentLoadingStrategy.isEffectivelyOffline ? "wifi.slash" : "wifi")
                        .foregroundStyle(networkMonitor.state.contentLoadingStrategy.isEffectivelyOffline ? .red : .green)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Network Status")
                            .font(.headline)
                        Text(networkMonitor.state.contentLoadingStrategy.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        offlineManager.toggleOfflineMode()
                    } label: {
                        Text(networkMonitor.state.contentLoadingStrategy.isEffectivelyOffline ? "Go Online" : "Go Offline")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(theme.accent.opacity(0.2))
                            .foregroundStyle(theme.accent)
                            .cornerRadius(8)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Connection")
            }
            
            // MARK: - State Details Section
            Section {
                LabeledRow(
                    label: "Fully Connected",
                    value: networkMonitor.state.isFullyConnected ? "Yes" : "No",
                    valueColor: networkMonitor.state.isFullyConnected ? .green : .red
                )
                
                LabeledRow(
                    label: "Configured",
                    value: networkMonitor.state.isConfigured ? "Yes" : "No",
                    valueColor: networkMonitor.state.isConfigured ? .green : .orange
                )
                
                LabeledRow(
                    label: "Loading Strategy",
                    value: networkMonitor.state.contentLoadingStrategy.displayName
                )
            } header: {
                Text("Status Details")
            }
            
            // MARK: - Connection Test Section
            Section {
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await connectionManager.testConnection(credentials: AppConfig.shared.getCredentials())
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if connectionManager.isTestingConnection {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Testing...")
                            } else {
                                Image(systemName: "network")
                                Text("Test Connection")
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(connectionManager.isTestingConnection)
                    
                    if !connectionManager.connectionStatusText.isEmpty {
                        Text(connectionManager.connectionStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
            } header: {
                Text("Diagnostics")
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Helper View

struct LabeledRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
                .fontWeight(.semibold)
        }
    }
}
