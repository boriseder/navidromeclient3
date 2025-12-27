import SwiftUI

struct OfflineReasonBanner: View {
    // FIX: Swift 6 Environment
    @Environment(OfflineManager.self) private var offlineManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    
    var body: some View {
        if offlineManager.isOfflineMode {
            HStack {
                Image(systemName: "wifi.slash")
                Text("Offline Mode")
                Spacer()
                Button("Go Online") {
                    offlineManager.switchToOnlineMode()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.orange.opacity(0.2))
        }
    }
}
