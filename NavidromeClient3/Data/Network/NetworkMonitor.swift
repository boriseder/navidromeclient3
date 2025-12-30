//
//  NetworkMonitor.swift
//  NavidromeClient3
//
//  Swift 6: Added 'isConnected' convenience property
//

import Foundation
import Network
import SwiftUI
import Observation

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
    
    // FIX: Added convenience property used by Views
    var isConnected: Bool {
        state.hasInternet
    }
    
    var contentLoadingStrategy: ContentLoadingStrategy {
        state.contentLoadingStrategy
    }
    
    // Internal Infrastructure
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private var subsonicService: UnifiedSubsonicService?
    
    // Internal tracking
    private var hasInternet = false
    private var isServerReachable = true
    private var manualOfflineMode = false
    
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
        Task { await recheckConnection() }
    }
    
    func updateConfiguration(isConfigured: Bool) {
        updateState(isConfigured: isConfigured)
    }
    
    func setManualOfflineMode(_ enabled: Bool) {
        if !enabled {
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
        let internetAvailable = await checkInternetReachable()
        var serverAvailable = false
        
        if let service = subsonicService {
            if internetAvailable {
                serverAvailable = await service.ping()
            }
        } else {
            serverAvailable = true
        }
        
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
            state = newState
            
            if oldStrategy != state.contentLoadingStrategy {
                 NotificationCenter.default.post(
                    name: .contentLoadingStrategyChanged,
                    object: state.contentLoadingStrategy
                )
            }
        }
    }
    
    func reset() {
        isServerReachable = true
        manualOfflineMode = false
        updateState()
    }
}

extension Notification.Name {
    static let contentLoadingStrategyChanged = Notification.Name("contentLoadingStrategyChanged")
}
