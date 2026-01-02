//
//  NetworkDebugBanner.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Environment(Type.self)
//

import SwiftUI

struct NetworkDebugBanner: View {
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(OfflineManager.self) private var offlineManager
    @Environment(ConnectionViewModel.self) private var connectionManager

    @State private var health: ConnectionHealth?
    
    var body: some View {
        VStack(spacing: DSLayout.contentGap) {
            
            // MARK: - Network State Display
            HStack(spacing: DSLayout.tightGap) {
                Button {
                    offlineManager.toggleOfflineMode()
                } label: {
                    Image(systemName: networkMonitor.state.contentLoadingStrategy.isEffectivelyOffline ? "wifi.slash" : "wifi")
                        .font(DSText.subsectionTitle)
                        .foregroundColor(.white)
                }
                .padding(.leading, DSLayout.elementPadding)
                
                Divider()
                
                VStack(spacing: 4) {
                    DebugRow(label: "isFullyConnected", value: "\(networkMonitor.state.isFullyConnected)")
                    DebugRow(label: "isConfigured", value: "\(networkMonitor.state.isConfigured)")
                    DebugRow(label: "Strategy", value: networkMonitor.state.contentLoadingStrategy.displayName)
                }
                .padding(DSLayout.elementPadding)
            }
            .background(networkMonitor.state.contentLoadingStrategy.isEffectivelyOffline ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
            
            HStack {
                VStack(spacing: DSLayout.contentGap) {
                    Button {
                        Task {
                            await connectionManager.testConnection()
                        }
                    } label: {
                        Text("Test Connection")
                            .font(DSText.footnote)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .padding(.leading, DSLayout.elementPadding)
                    
                    if connectionManager.isTestingConnection {
                        ProgressView().tint(.white)
                    } else {
                        Text(connectionManager.connectionStatusText)
                            .font(DSText.fine)
                            .foregroundStyle(.white)
                    }
                }
            }
            .background(networkMonitor.state.contentLoadingStrategy.isEffectivelyOffline ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
        }
    }
}

struct DebugRow: View {
    let label: String
    let value: String
    private let labelWidth: CGFloat = 140

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .frame(width: labelWidth, alignment: .leading)
                .font(DSText.footnote)
                .foregroundColor(.white)

            Text(value)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .font(DSText.footnote)
                .foregroundColor(.white)
                .fontWeight(.bold)
        }
    }
}
