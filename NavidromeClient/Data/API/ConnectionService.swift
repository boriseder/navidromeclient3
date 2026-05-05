//
//  ConnectionService.swift
//  NavidromeClient
//
//  REFACTORED: Step 2 — NetworkActor
//  Observable UI state stays @MainActor.
//  All HTTP delegated to NetworkActor.
//

import Foundation
import CryptoKit
import Observation

@MainActor
@Observable
class ConnectionService {

    // MARK: - Observable UI State

    private(set) var isConnected = false
    private(set) var connectionQuality: ConnectionQuality = .unknown
    private(set) var lastSuccessfulConnection: Date?

    // MARK: - Network

    let network: NetworkActor

    enum ConnectionQuality: Sendable {
        case unknown, excellent, good, poor, timeout

        var description: String {
            switch self {
            case .unknown:   return "Unknown"
            case .excellent: return "Excellent"
            case .good:      return "Good"
            case .poor:      return "Poor"
            case .timeout:   return "Timeout"
            }
        }
    }

    // MARK: - Init

    init(baseURL: URL, username: String, password: String) {
        self.network = NetworkActor(
            baseURL: baseURL,
            username: username,
            password: password
        )
    }

    // MARK: - Connection Testing

    func testConnection() async -> ConnectionTestResult {
        let startTime = Date()

        do {
            let pingInfo = try await network.ping()

            let responseTime = Date().timeIntervalSince(startTime)
            updateConnectionState(responseTime: responseTime, success: true)

            return .success(ConnectionInfo(
                version: pingInfo.version,
                type: pingInfo.type,
                serverVersion: pingInfo.serverVersion,
                openSubsonic: pingInfo.openSubsonic
            ))
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            updateConnectionState(responseTime: elapsed, success: false)
            return .failure(SubsonicError.from(error).asConnectionError)
        }
    }

    func ping() async -> Bool {
        let startTime = Date()
        do {
            _ = try await network.ping()
            updateConnectionState(responseTime: Date().timeIntervalSince(startTime), success: true)
            return true
        } catch {
            updateConnectionState(responseTime: Date().timeIntervalSince(startTime), success: false)
            return false
        }
    }

    // MARK: - URL / Auth pass-through (kept for callers that need them)

    func buildURL(endpoint: String, params: [String: String] = [:]) -> URL? {
        network.buildURL(endpoint: endpoint, params: params)
    }

    func getAuthHeader() -> [String: String] {
        network.authHeader()
    }

    // MARK: - Health

    func performHealthCheck() async -> ConnectionHealth {
        let startTime = Date()
        let reachable = await ping()
        let elapsed = Date().timeIntervalSince(startTime)
        return ConnectionHealth(
            isConnected: reachable,
            quality: determineQuality(responseTime: elapsed, success: reachable),
            responseTime: elapsed,
            lastSuccessfulConnection: lastSuccessfulConnection
        )
    }

    // MARK: - Private

    private func updateConnectionState(responseTime: TimeInterval, success: Bool) {
        isConnected = success
        connectionQuality = determineQuality(responseTime: responseTime, success: success)
        if success { lastSuccessfulConnection = Date() }
    }

    private func determineQuality(responseTime: TimeInterval, success: Bool) -> ConnectionQuality {
        guard success else { return .timeout }
        switch responseTime {
        case 0..<0.5:  return .excellent
        case 0.5..<1.5: return .good
        default:        return .poor
        }
    }
}

// MARK: - Supporting Types

enum ConnectionTestResult: Sendable {
    case success(ConnectionInfo)
    case failure(ConnectionError)
}

struct ConnectionInfo: Sendable {
    let version: String
    let type: String
    let serverVersion: String
    let openSubsonic: Bool
}

enum ConnectionError: Sendable {
    case invalidCredentials
    case serverUnreachable
    case timeout
    case networkError(String)
    case invalidServerType
    case invalidURL
    
    var userMessage: String {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .serverUnreachable:
            return "Server unreachable"
        case .timeout:
            return "Connection timeout"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidServerType:
            return "Invalid server response"
        case .invalidURL:
            return "Invalid server URL"
        }
    }
}

struct ConnectionHealth: Sendable {
    let isConnected: Bool
    let quality: ConnectionService.ConnectionQuality
    let responseTime: TimeInterval
    let lastSuccessfulConnection: Date?
    
    var healthScore: Double {
        guard isConnected else { return 0.0 }
        
        switch quality {
        case .unknown: return 0.0
        case .excellent: return 1.0
        case .good: return 0.75
        case .poor: return 0.4
        case .timeout: return 0.0
        }
    }
    
    var statusDescription: String {
        if !isConnected {
            return "Disconnected"
        }
        
        let timeStr = String(format: "%.0f", responseTime * 1000)
        return "\(quality.description) (\(timeStr)ms)"
    }
}

extension String {
    func md5() -> String {
        let digest = Insecure.MD5.hash(data: Data(self.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
