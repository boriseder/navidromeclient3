//
//  NetworkMonitor.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Compliance
//  - Removed redundant try/catch for ping()
//

import Foundation
import Network
import Observation

@MainActor
@Observable
class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    // MARK: - Observable Properties
    private(set) var state: NetworkState = .initial
    
    // Derived properties for easier view consumption
    var isConnected: Bool { state.isConnected }
    var isConfigured: Bool { state.isConfigured }
    var currentConnectionType: NetworkState.ConnectionType { state.connectionType }
    var contentLoadingStrategy: ContentLoadingStrategy { state.contentLoadingStrategy }
    
    // Convenience for UI
    var canLoadOnlineContent: Bool {
        return contentLoadingStrategy == .online
    }
    
    var shouldLoadOnlineContent: Bool {
        return canLoadOnlineContent
    }
    
    var connectionStatusDescription: String {
        if !state.isConnected { return "No Internet Connection" }
        switch state.serverReachability {
        case .reachable: return "Online"
        case .unreachable: return "Server Unreachable"
        case .unknown: return "Checking..."
        }
    }
    
    // MARK: - Internal
    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private let workerQueue = DispatchQueue(label: "NetworkMonitor")
    @ObservationIgnored private weak var service: UnifiedSubsonicService?
    
    private init() {
        startMonitoring()
    }
    
    func configureService(_ service: UnifiedSubsonicService?) {
        self.service = service
        Task { await checkServerReachability() }
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.updateNetworkStatus(path: path)
            }
        }
        monitor.start(queue: workerQueue)
    }
    
    func reset() {
        state = .initial
        Task { await checkServerReachability() }
    }
    
    private func updateNetworkStatus(path: NWPath) {
        let isConnected = path.status == .satisfied
        let type: NetworkState.ConnectionType = path.usesInterfaceType(.wifi) ? .wifi : (path.usesInterfaceType(.cellular) ? .cellular : .other)
        
        // Update basic connectivity
        var newState = self.state
        newState.isConnected = isConnected
        newState.connectionType = type
        
        // If we regained connection, check server
        if isConnected && !self.state.isConnected {
            self.state = newState // Update immediately to show "Connecting..." state if needed
            Task { await checkServerReachability() }
        } else {
            self.state = newState
            updateStrategy()
        }
    }
    
    func recheckConnection() async {
        await checkServerReachability()
    }
    
    private func checkServerReachability() async {
        // Don't ping if no network
        guard state.isConnected else {
            updateStrategy()
            return
        }
        
        // Don't ping if not configured
        guard state.isConfigured, let service = service else {
            updateStrategy()
            return
        }
        
        // Fixed: ping() returns Bool and does not throw, so no try/catch needed
        let isReachable = await service.ping()
        state.serverReachability = isReachable ? .reachable : .unreachable
        
        updateStrategy()
    }
    
    func updateConfiguration(isConfigured: Bool) {
        state.isConfigured = isConfigured
        updateStrategy()
    }
    
    private func updateStrategy() {
        if !state.isConfigured {
            state.contentLoadingStrategy = .setupRequired
            return
        }
        
        if !state.isConnected {
            state.contentLoadingStrategy = .offlineOnly(reason: .noNetwork)
            return
        }
        
        switch state.serverReachability {
        case .reachable:
            state.contentLoadingStrategy = .online
        case .unreachable:
            state.contentLoadingStrategy = .offlineOnly(reason: .serverUnreachable)
        case .unknown:
            state.contentLoadingStrategy = .offlineOnly(reason: .serverUnreachable)
        }
    }
}
