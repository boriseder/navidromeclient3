//
//  NetworkMonitor.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Strictly MainActor for state updates
//  - Detached tasks for non-blocking checks
//  - Thread-safe I/O
//

import Foundation
import Network
import SwiftUI

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    // MARK: - Single Source of Truth
    @Published private(set) var state: NetworkState
    
    // MARK: - Network Monitoring Infrastructure
    private let monitor = NWPathMonitor()
    // DispatchQueue is Sendable
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Internal Hardware State
    private var hasInternet = false              // Device has internet connection
    private var isServerReachable = true         // Navidrome server responds (optimistic default)
    private var connectionType: NetworkConnectionType = .unknown
    private var manualOfflineMode = false

    // Rate limiting for internet checks
    private var lastInternetCheck: Date?
    private let minimumCheckInterval: TimeInterval = 3.0
    
    // Server health tracking
    private weak var subsonicService: UnifiedSubsonicService?
    
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
    
    private init() {
        // Start with conservative state
        self.state = NetworkState(
            hasInternet: false,
            isServerReachable: false,
            isConfigured: false,
            manualOfflineMode: false
        )
        
        AppLogger.network.info("[NetworkMonitor] Initializing...")
        startNetworkMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Public API - State Queries
    
    var shouldLoadOnlineContent: Bool {
        state.contentLoadingStrategy.shouldLoadOnlineContent
    }
    
    var contentLoadingStrategy: ContentLoadingStrategy {
        state.contentLoadingStrategy
    }
    
    var currentConnectionType: NetworkConnectionType {
        connectionType
    }
    
    var canLoadOnlineContent: Bool {
        state.isFullyConnected && state.isConfigured
    }
    
    var connectionStatusDescription: String {
        state.contentLoadingStrategy.displayName
    }
    
    // MARK: - Service Configuration

    func configureService(_ service: UnifiedSubsonicService?) {
        self.subsonicService = service
        AppLogger.network.info("[NetworkMonitor] Service configured: \(service != nil ? "yes" : "no")")
    }
    
    
    // MARK: - Public API - State Updates
    
    func initialize(isConfigured: Bool) {
        updateState(isConfigured: isConfigured)
        AppLogger.network.info("[NetworkMonitor] Explicitly initialized (configured: \(isConfigured))")
    }
    
    func updateConfiguration(isConfigured: Bool) {
        updateState(isConfigured: isConfigured)
    }
    
    func reportServerError() {
        isServerReachable = false
        updateState()
        AppLogger.network.info("[NetworkMonitor] Server error reported")
    }
    
    func clearServerErrors() {
        isServerReachable = true
        updateState()
        AppLogger.network.info("[NetworkMonitor] Server errors cleared")
    }
    
    func setManualOfflineMode(_ enabled: Bool) {
        if !enabled {
            // User wants to go online
            // CRITICAL: Verify BOTH internet AND server are actually available!
            
            let hasInternetCached = state.hasInternet
            
            if !hasInternetCached {
                AppLogger.network.info("[NetworkMonitor] Cached state says offline - triggering recheck...")
                
                // Trigger immediate network recheck
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    await self.recheckConnection()
                    
                    // After recheck, verify BOTH conditions
                    if self.state.hasInternet && self.isServerReachable {
                        AppLogger.network.info("[NetworkMonitor] Network and server available after recheck")
                        self.manualOfflineMode = false
                        self.updateState()
                        AppLogger.network.info("[NetworkMonitor] Manual offline mode: disabled (after recheck)")
                    } else if !self.state.hasInternet {
                        AppLogger.network.info("[NetworkMonitor] Cannot go online: no internet connection (verified)")
                    } else if !self.isServerReachable {
                        AppLogger.network.info("[NetworkMonitor] Cannot go online: server unreachable (verified)")
                    }
                }
                return
            }
            
            // If we have internet but server is unreachable, prevent going online
            if !isServerReachable {
                AppLogger.network.info("[NetworkMonitor] Cannot go online: server unreachable")
                return  // ✅ Block the attempt!
            }
            
            // Both internet AND server available - allow going online
            manualOfflineMode = false
            updateState()
            AppLogger.network.info("[NetworkMonitor] Manual offline mode: disabled")
            return
        }
        
        // Going offline is always allowed
        manualOfflineMode = enabled
        updateState()
        AppLogger.network.info("[NetworkMonitor] Manual offline mode: enabled")
    }
    
    func reset() {
        isServerReachable = true
        manualOfflineMode = false
        updateState()
        AppLogger.network.info("[NetworkMonitor] Reset completed")
    }
    
    func recheckConnection() async {
        // Force new checks
        lastInternetCheck = nil
        
        // Detached task allows background execution, but we must be careful with state updates
        await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            // Safe access to NWPathMonitor (thread-safe class)
            let currentPath = self.monitor.currentPath
            var pathSatisfied = currentPath.status == .satisfied
            
            // If path not satisfied, try direct internet check anyway
            if !pathSatisfied {
                AppLogger.network.debug("[NetworkMonitor] Path not satisfied - trying direct check...")
                
                // Hop back to MainActor to access `checkInternetReachable` (which touches isolated state)
                let directCheck = await self.checkInternetReachable(force: true)
                
                if directCheck {
                    AppLogger.network.info("[NetworkMonitor] Internet available despite path status")
                    pathSatisfied = true
                }
            }
            
            // Check internet availability (hops to MainActor)
            let internetAvailable = pathSatisfied ? await self.checkInternetReachable(force: true) : false
            
            // Check server availability (only if internet is available)
            // Capture service reference safely on MainActor
            let service = await MainActor.run { self.subsonicService }
            
            let serverAvailable: Bool
            if internetAvailable, let service = service {
                serverAvailable = await service.ping()
                AppLogger.network.debug("[NetworkMonitor] Server ping: \(serverAvailable)")
            } else {
                // No internet or no service configured (setup mode) - treat as available
                serverAvailable = service == nil
            }
            
            // Final state update on MainActor
            await MainActor.run {
                let wasInternetAvailable = self.hasInternet
                let wasServerReachable = self.isServerReachable
                
                // Update both states independently
                self.hasInternet = internetAvailable
                self.isServerReachable = serverAvailable
                
                self.connectionType = self.getConnectionType(currentPath)
                
                // Log state changes
                if internetAvailable && !wasInternetAvailable {
                    AppLogger.network.info("[NetworkMonitor] Internet restored: \(self.connectionType.displayName)")
                } else if !internetAvailable && wasInternetAvailable {
                    AppLogger.network.warn("[NetworkMonitor] Internet lost")
                }
                
                if internetAvailable && serverAvailable && !wasServerReachable {
                    AppLogger.network.info("[NetworkMonitor] Server became reachable")
                } else if internetAvailable && !serverAvailable && wasServerReachable {
                    AppLogger.network.warn("[NetworkMonitor] Server became unreachable")
                }
                
                self.updateState()
            }
        }.value
    }
    
    // MARK: - State Update
    
    private func updateState(isConfigured: Bool? = nil) {
        let newState = NetworkState(
            hasInternet: hasInternet,
            isServerReachable: isServerReachable,
            isConfigured: isConfigured ?? state.isConfigured,
            manualOfflineMode: manualOfflineMode
        )
        
        if newState != state {
            let oldStrategy = state.contentLoadingStrategy
            let newStrategy = newState.contentLoadingStrategy
            
            state = newState
            
            if oldStrategy != newStrategy {
                AppLogger.network.info("[NetworkMonitor] Strategy changed: \(oldStrategy.displayName) -> \(newStrategy.displayName)")
                
                NotificationCenter.default.post(
                    name: .contentLoadingStrategyChanged,
                    object: newStrategy
                )
            }
        }
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let pathSatisfied = path.status == .satisfied
                self.connectionType = self.getConnectionType(path)
                
                if pathSatisfied {
                    let internetAvailable = await self.checkInternetReachable()
                    let wasInternetAvailable = self.hasInternet
                    
                    // Also check server if we have a service configured
                    let serverAvailable: Bool
                    if internetAvailable, let service = self.subsonicService {
                        serverAvailable = await service.ping()
                    } else {
                        serverAvailable = self.subsonicService == nil
                    }
                    
                    self.hasInternet = internetAvailable
                    self.isServerReachable = serverAvailable
                    
                    if internetAvailable && !wasInternetAvailable {
                        AppLogger.network.info("[NetworkMonitor] Internet restored: \(self.connectionType.displayName)")
                    }
                } else {
                    if self.hasInternet {
                        AppLogger.network.info("[NetworkMonitor] Network interface lost")
                    }
                    self.hasInternet = false
                    self.isServerReachable = false
                }
                
                self.updateState()
            }
        }

        
        monitor.start(queue: queue)
        
        // Initial check
        Task { @MainActor in
            await Task.yield() // Let monitor start
            
            let initialPath = monitor.currentPath
            self.connectionType = self.getConnectionType(initialPath)
            
            if initialPath.status == .satisfied {
                self.hasInternet = await self.checkInternetReachable()
            } else {
                self.hasInternet = false
            }
            
            self.updateState()
            AppLogger.network.info("[NetworkMonitor] Initial state: \(self.hasInternet ? "Has Internet" : "No Internet") (\(self.connectionType.displayName))")
        }
    }
    
    // MARK: - Internet Reachability Check
    
    private func checkInternetReachable(force: Bool = false) async -> Bool {
        // Rate limiting
        if !force, let lastCheck = lastInternetCheck,
           Date().timeIntervalSince(lastCheck) < minimumCheckInterval {
            return hasInternet
        }
        
        lastInternetCheck = Date()
        
        // Try multiple endpoints for robustness
        if await checkURL("https://www.google.com/generate_204", expecting: 204) {
            return true
        }
        
        if await checkURL("http://captive.apple.com/hotspot-detect.html", expecting: 200) {
            return true
        }
        
        if await checkURL("https://1.1.1.1/", expecting: nil) {
            return true
        }
        
        return false
    }
    
    private nonisolated func checkURL(_ urlString: String, expecting statusCode: Int?) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if let expectedCode = statusCode {
                    return httpResponse.statusCode == expectedCode
                } else {
                    return (200...299).contains(httpResponse.statusCode) ||
                           httpResponse.statusCode == 301 ||
                           httpResponse.statusCode == 302
                }
            }
            
            return false
        } catch {
            return false
        }
    }
    
    private func getConnectionType(_ path: NWPath) -> NetworkConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
    
    // MARK: - Diagnostics
    
    func getDiagnostics() -> NetworkDiagnostics {
        NetworkDiagnostics(
            state: state,
            connectionType: connectionType,
            hasInternet: hasInternet,
            isServerReachable: isServerReachable,
            manualOfflineMode: manualOfflineMode,
            lastInternetCheck: lastInternetCheck
        )
    }
    
    struct NetworkDiagnostics {
        let state: NetworkState
        let connectionType: NetworkConnectionType
        let hasInternet: Bool
        let isServerReachable: Bool
        let manualOfflineMode: Bool
        let lastInternetCheck: Date?
        
        var summary: String {
            var status: [String] = []
            
            status.append("Internet: \(hasInternet ? "Available" : "Unavailable")")
            status.append("Server: \(isServerReachable ? "Reachable" : "Unreachable")")
            status.append("Type: \(connectionType.displayName)")
            status.append("Configured: \(state.isConfigured ? "Yes" : "No")")
            status.append("Strategy: \(state.contentLoadingStrategy.displayName)")
            
            if manualOfflineMode {
                status.append("Manual Offline: Yes")
            }
            if let lastCheck = lastInternetCheck {
                let ago = Date().timeIntervalSince(lastCheck)
                status.append("Last Check: \(String(format: "%.1fs ago", ago))")
            }
            
            return status.joined(separator: " | ")
        }
    }
}

// MARK: -
