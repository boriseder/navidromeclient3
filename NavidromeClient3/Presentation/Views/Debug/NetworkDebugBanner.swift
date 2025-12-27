import SwiftUI

struct NetworkDebugBanner: View {
    // FIX: Swift 6 Environment
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(OfflineManager.self) private var offlineManager
    @Environment(ConnectionViewModel.self) private var connectionManager

    var body: some View {
        VStack(spacing: 4) {
            Text("Network Strategy: \(networkMonitor.contentLoadingStrategy.displayName)")
            
            HStack {
                Text("Internet: \(networkMonitor.state.hasInternet ? "Yes" : "No")")
                Text("Server: \(networkMonitor.state.isServerReachable ? "Yes" : "No")")
            }
            
            Button("Check Connection") {
                // Task { await connectionManager.testConnection() }
            }
        }
        .font(.caption)
        .padding()
        .background(Color.black.opacity(0.7))
        .foregroundColor(.white)
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
