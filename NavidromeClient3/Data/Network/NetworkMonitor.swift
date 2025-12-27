//
//  NetworkMonitor.swift
//  NavidromeClient
//
//  Swift 6: @Observable & Actor Integration
//  State of the Art Concurrency
//

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
    // @Observable automatically tracks changes to these properties
    var state: NetworkState
    var connectionType: NetworkConnectionType = .unknown
    
    // Internal Infrastructure
    private let monitor = NWPathMonitor()
    // NWPathMonitor requires a specific queue, we create one.
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // Reference to the service actor
    private var subsonicService: UnifiedSubsonicService?
    
    // Internal tracking
    private var hasInternet = false
    private var isServerReachable = true
    private var manualOfflineMode = false
    
    // Rate limiting
    private var lastInternetCheck: Date?
    private let minimumCheckInterval: TimeInterval = 3.0
    
    // MARK: - Initialization
    private init() {
        self.state = NetworkState(
            hasInternet: false,
            isServerReachable: false,
            isConfigured: false,
            manualOfflineMode: false
        )
        
        AppLogger.network.info("[NetworkMonitor] Initializing (Swift 6)...")
        startNetworkMonitoring()
    }
    
    // MARK: - Configuration
    func configureService(_ service: UnifiedSubsonicService?) {
        self.subsonicService = service
        // Trigger recheck when service changes
        Task { await recheckConnection() }
    }
    
    func updateConfiguration(isConfigured: Bool) {
        updateState(isConfigured: isConfigured)
    }
    
    func setManualOfflineMode(_ enabled: Bool) {
        if !enabled {
            // User wants to go online: Verify connectivity first
             Task {
                 await recheckConnection()
                 if state.hasInternet && isServerReachable {
                     self.manualOfflineMode = false
                     self.updateState()
                 }
             }
        } else {
            self.manualOfflineMode = enabled
            updateState()
        }
    }
    
    // MARK: - Observation Helpers
    var shouldLoadOnlineContent: Bool { state.contentLoadingStrategy.shouldLoadOnlineContent }
    var canLoadOnlineContent: Bool { state.isFullyConnected && state.isConfigured }
    
    // MARK: - Monitoring
    func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            // Dispatch to MainActor to update our @Observable state
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
        
        // When physical path changes, recheck logical connectivity
        Task { await recheckConnection() }
    }
    
    func recheckConnection() async {
        // 1. Check Internet
        let internetAvailable = await checkInternetReachable()
        
        // 2. Check Server (Actor Call)
        var serverAvailable = false
        
        // We capture the optional service reference safely on MainActor
        if let service = subsonicService {
            if internetAvailable {
                // AWAIT the actor.
                // Since UnifiedSubsonicService is now an Actor, this must be awaited.
                serverAvailable = await service.ping()
            }
        } else {
            // No service configured (setup mode) - assume server "logic" is available locally
            serverAvailable = true
        }
        
        // 3. Update State (we are on MainActor)
        self.hasInternet = internetAvailable
        self.isServerReachable = serverAvailable
        updateState()
    }
    
    private func checkInternetReachable(force: Bool = false) async -> Bool {
        if !force, let lastCheck = lastInternetCheck, Date().timeIntervalSince(lastCheck) < minimumCheckInterval {
            return hasInternet
        }
        lastInternetCheck = Date()
        
        guard let url = URL(string: "https://www.google.com/generate_204") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        do {
            // Use shared session (non-actor) for simple connectivity check
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 204
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
            
            // @Observable triggers UI updates here
            state = newState
            
            // Legacy support: Post notification for managers not yet fully migrated
            if oldStrategy != state.contentLoadingStrategy {
                 NotificationCenter.default.post(
                    name: .contentLoadingStrategyChanged,
                    object: state.contentLoadingStrategy
                )
            }
        }
    }
    
    // MARK: - Reset
    func reset() {
        isServerReachable = true
        manualOfflineMode = false
        updateState()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let contentLoadingStrategyChanged = Notification.Name("contentLoadingStrategyChanged")
}
