import SwiftUI

struct NetworkDebugBanner: View {
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var offlineManager: OfflineManager
    @EnvironmentObject private var connectionManager: ConnectionViewModel

    @State private var health: ConnectionHealth?
    
    var body: some View {
        VStack(spacing: DSLayout.contentGap) {
            
            // MARK: - Network State Display
            HStack(spacing: DSLayout.tightGap) {
                Button {
                    Task {
                        offlineManager.toggleOfflineMode()
                    }
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
                    DebugRow(label: "hasInternet", value: "\(networkMonitor.state.hasInternet)")
                    DebugRow(label: "isServerReachable", value: "\(networkMonitor.state.isServerReachable)")
                    DebugRow(label: "manualOfflineMode", value: "\(networkMonitor.state.manualOfflineMode)")
                    DebugRow(label: "contentLoadingStrategy", value: strategyLabel(networkMonitor.state.contentLoadingStrategy))
                    DebugRow(label: "reason", value: reasonLabelIfPresent(networkMonitor.state.contentLoadingStrategy))
                    DebugRow(label: "isEffectivelyOffline", value: "\(networkMonitor.state.contentLoadingStrategy.isEffectivelyOffline)")
                    DebugRow(label: "shouldLoadOnlineContent", value: "\(networkMonitor.state.contentLoadingStrategy.shouldLoadOnlineContent)")
                    DebugRow(label: "displayName", value: networkMonitor.state.contentLoadingStrategy.displayName)
                }
                .padding(DSLayout.elementPadding)
                
            }
            .background(networkMonitor.state.contentLoadingStrategy.isEffectivelyOffline ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
            
            HStack {
                VStack(spacing: DSLayout.contentGap) {
                    if let h = health {
                        VStack(alignment: .leading) {
                            Text("Connected: \(h.isConnected ? "ja" : "nein")")
                            Text("Quality: \(String(describing: h.quality))")
                            Text("Response: \(h.responseTime)")
                            Text("Last success: \(String(describing: h.lastSuccessfulConnection))")
                        }
                    }
                    
                    Button {
                        Task {
                            await connectionManager.performQuickHealthCheck()
                        }
                    } label: {
                        Text("Call performConnectionHealthCheck()")
                            .font(DSText.footnote)
                            .foregroundColor(.white)
                    }
                    .padding(.leading, DSLayout.elementPadding)
                }
            }
            .background(networkMonitor.state.contentLoadingStrategy.isEffectivelyOffline ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
        }
    }
    
    func strategyLabel(_ strategy: ContentLoadingStrategy) -> String {
        switch strategy {
        case .online:
            return "online"

        case .offlineOnly(let reason):
            return "offlineOnly: \(reasonLabel(reason))"

        case .setupRequired:
            return "setupRequired"
        }
    }
    
    func reasonLabelIfPresent(_ strategy: ContentLoadingStrategy) -> String {
        switch strategy {
        case .offlineOnly(let reason):
            return reasonLabel(reason)
        default:
            return "none"
        }
    }

    func reasonLabel(_ reason: ContentLoadingStrategy.OfflineReason) -> String {
        switch reason {
        case .noNetwork: return "noNetwork"
        case .serverUnreachable: return "serverUnreachable"
        case .userChoice: return "userChoice"
        }
    }
}

struct DebugRow: View {
    let label: String
    let value: String
    private let labelWidth: CGFloat = 180

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
