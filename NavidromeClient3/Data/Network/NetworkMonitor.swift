import Foundation
import Network
import SwiftUI
import Observation

// FIX: Define this OUTSIDE the class.
// Must be Sendable to be safe in the new concurrency model.
enum NetworkConnectionType: Sendable {
    case wifi, cellular, ethernet, unknown
    
    var displayName: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .ethernet: return "Ethernet"
        case .unknown: return "Unknown"
        }
    }
}

@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    // MARK: - State
    var state: NetworkState
    var connectionType: NetworkConnectionType = .unknown
    
    // Internal Infrastructure
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // Reference to the service actor
    private var subsonicService: UnifiedSubsonicService?
    
    // Internal tracking
    private var hasInternet = false
    private var isServerReachable = true
    private var manualOfflineMode = false
    
    // MARK: - Initialization
    private init() {
        self.state = NetworkState(
            hasInternet: false,
            isServerReachable: false,
            isConfigured: false,
            manualOfflineMode: false
        )
        startNetworkMonitoring()
    }
    
    // MARK: - Configuration
    func configureService(_ service: UnifiedSubsonicService?) {
        self.subsonicService = service
        Task { await recheckConnection() }
    }
    
    func updateConfiguration(isConfigured: Bool) {
        updateState(isConfigured: isConfigured)
    }
    
    func setManualOfflineMode(_ enabled: Bool) {
        self.manualOfflineMode = enabled
        updateState()
    }
    
    // MARK: - Observation Helpers
    var shouldLoadOnlineContent: Bool { state.contentLoadingStrategy.shouldLoadOnlineContent }
    var canLoadOnlineContent: Bool { state.isFullyConnected && state.isConfigured }
    
    // MARK: - Monitoring
    func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func handlePathUpdate(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) { connectionType = .wifi }
        else if path.usesInterfaceType(.cellular) { connectionType = .cellular }
        else if path.usesInterfaceType(.wiredEthernet) { connectionType = .ethernet }
        else { connectionType = .unknown }
        
        Task { await recheckConnection() }
    }
    
    func recheckConnection() async {
        // 1. Check Internet
        let internetAvailable = await checkInternetReachable()
        
        // 2. Check Server (Actor Call)
        var serverAvailable = false
        if internetAvailable, let service = subsonicService {
            serverAvailable = await service.ping()
        } else if internetAvailable && subsonicService == nil {
            // If we have internet but no service configured, we assume the "server" (auth) is reachable conceptually
            serverAvailable = true
        }
        
        // 3. Update State
        self.hasInternet = internetAvailable
        self.isServerReachable = serverAvailable
        updateState()
    }
    
    private func checkInternetReachable() async -> Bool {
        guard let url = URL(string: "https://www.google.com") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    private func updateState(isConfigured: Bool? = nil) {
        let newState = NetworkState(
            hasInternet: hasInternet,
            isServerReachable: isServerReachable,
            isConfigured: isConfigured ?? state.isConfigured,
            manualOfflineMode: manualOfflineMode
        )
        
        if newState != state {
            let oldStrategy = state.contentLoadingStrategy
            state = newState
            
            if oldStrategy != state.contentLoadingStrategy {
                 NotificationCenter.default.post(
                    name: .contentLoadingStrategyChanged,
                    object: state.contentLoadingStrategy
                )
            }
        }
    }
}
