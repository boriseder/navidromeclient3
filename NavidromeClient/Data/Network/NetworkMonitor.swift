//
//  NetworkMonitor.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Compliance
//  - FIXED: Prevents WelcomeView flash on startup
//  - Uses proper initialization state
//

import Foundation
import Network
import Observation

@MainActor
@Observable
class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    // MARK: - Observable Properties
    private(set) var state: AppNetworkState = .initial
    
    // Derived properties for easier view consumption
    var isConnected: Bool { state.isConnected }
    var isConfigured: Bool { state.isConfigured }
    var currentConnectionType: AppNetworkState.ConnectionType { state.connectionType }
    var contentLoadingStrategy: ContentLoadingStrategy { state.contentLoadingStrategy }
    
    // Convenience for UI
    var canLoadOnlineContent: Bool {
        return contentLoadingStrategy == .online
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
    @ObservationIgnored private var pendingServerCheckTask: Task<Void, Never>? // <-- ADD THIS
    
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
        let type: AppNetworkState.ConnectionType = path.usesInterfaceType(.wifi) ? .wifi : (path.usesInterfaceType(.cellular) ? .cellular : .other)
        
        // Update basic connectivity
        var newState = self.state
        newState.isConnected = isConnected
        newState.connectionType = type
        self.state = newState
        
        guard isConnected else {
            pendingServerCheckTask?.cancel()
            updateStrategy()
            return
        }
        
        // Debounce: cancel any in-flight check and wait 1.5s before pinging
        pendingServerCheckTask?.cancel()
        pendingServerCheckTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s debounce
            guard !Task.isCancelled else { return }
            await self?.checkServerReachability()
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
        
        let isReachable = await service.ping()
        state.serverReachability = isReachable ? .reachable : .unreachable
        
        updateStrategy()
    }
    
    func updateConfiguration(isConfigured: Bool) {
        state.isConfigured = isConfigured
        updateStrategy()
    }
    
    private func updateStrategy() {
        // Directly modify the struct property
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
