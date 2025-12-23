//
//  ConnectionService.swift
//  NavidromeClient
//
//  Optimized: Single request, proper error handling, accurate timing
//

import Foundation
import CryptoKit

@MainActor
class ConnectionService: ObservableObject {
    private let baseURL: URL
    private let username: String
    private let password: String
    private let session: URLSession
    
    // MARK: - Connection State
    @Published private(set) var isConnected = false
    @Published private(set) var connectionQuality: ConnectionQuality = .unknown
    @Published private(set) var lastSuccessfulConnection: Date?

    enum ConnectionQuality {
        case unknown, excellent, good, poor, timeout
        
        var description: String {
            switch self {
            case .unknown: return "Unknown"
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .poor: return "Poor"
            case .timeout: return "Timeout"
            }
        }
    }

    // MARK: - Initialization
    init(baseURL: URL, username: String, password: String) {
        self.baseURL = baseURL
        self.username = username
        self.password = password
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpAdditionalHeaders = [
            "User-Agent": "NavidromeClient/1.0 iOS",
            "Accept": "application/json"
        ]
        config.urlCache = nil
        config.httpCookieAcceptPolicy = .never
        
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - CONNECTION TESTING (OPTIMIZED)
    
    func testConnection() async -> ConnectionTestResult {
        let startTime = Date()
        
        do {
            // Single request - ping provides all needed info
            let url = buildURL(endpoint: "ping")!
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.serverUnreachable)
            }
            
            // Check HTTP status
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    return .failure(.invalidCredentials)
                }
                return .failure(.serverUnreachable)
            }
            
            // Parse PingInfo
            let pingResponse = try JSONDecoder().decode(
                SubsonicResponse<PingInfo>.self,
                from: data
            )
            let pingInfo = pingResponse.subsonicResponse
            
            // Additionally check for Subsonic-level errors
            if let errorCheck = try? JSONDecoder().decode(
                SubsonicResponse<SubsonicResponseContent>.self,
                from: data
            ), errorCheck.subsonicResponse.status == "failed" {
                if let error = errorCheck.subsonicResponse.error {
                    AppLogger.ui.error("❌ Subsonic error: code=\(error.code), message=\(error.message)")
                    
                    if error.code == 40 || error.code == 41 {
                        return .failure(.invalidCredentials)
                    }
                    return .failure(.networkError(error.message))
                }
            }
            
            // Success!
            let responseTime = Date().timeIntervalSince(startTime)
            updateConnectionState(responseTime: responseTime, success: true)
            
            let connectionInfo = ConnectionInfo(
                version: pingInfo.version,
                type: pingInfo.type,
                serverVersion: pingInfo.serverVersion,
                openSubsonic: pingInfo.openSubsonic
            )
            
            return .success(connectionInfo)
            
        } catch {
            let failureTime = Date().timeIntervalSince(startTime)
            updateConnectionState(responseTime: failureTime, success: false)
            
            // Convert error using new consolidated system
            let subsonicError = SubsonicError.from(error)
            return .failure(subsonicError.asConnectionError)
        }
    }

    func ping() async -> Bool {
        let startTime = Date()
        
        do {
            _ = try await pingWithInfo()
            let responseTime = Date().timeIntervalSince(startTime)
            updateConnectionState(responseTime: responseTime, success: true)
            return true
        } catch {
            let failureTime = Date().timeIntervalSince(startTime)
            updateConnectionState(responseTime: failureTime, success: false)
            return false
        }
    }
    
    private func pingWithInfo() async throws -> PingInfo {
        let url = buildURL(endpoint: "ping")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SubsonicError.unauthorized
        }
        
        let decoded = try JSONDecoder().decode(SubsonicResponse<PingInfo>.self, from: data)
        return decoded.subsonicResponse
    }
    
    // MARK: - URL BUILDING & SECURITY
    
    func buildURL(endpoint: String, params: [String: String] = [:]) -> URL? {
        guard validateEndpoint(endpoint) else {
            AppLogger.general.info("Invalid endpoint: \(endpoint)")
            return nil
        }
        
        guard var components = URLComponents(string: baseURL.absoluteString) else {
            return nil
        }
        
        components.path = "/rest/\(endpoint).view"
        
        let salt = generateSecureSalt()
        let token = (password + salt).md5()
        
        var queryItems = [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "NavidromeClient")
        ]
        
        // Only add format parameter for non-stream endpoints
        if endpoint != "stream" && endpoint != "download" {
            queryItems.append(URLQueryItem(name: "f", value: "json"))
        }
        
        for (key, value) in params {
            guard validateParameter(key: key, value: value) else {
                AppLogger.general.info("Invalid parameter: \(key)")
                continue
            }
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        components.queryItems = queryItems
        return components.url
    }

    // MARK: - HEALTH MONITORING
    
    func performHealthCheck() async -> ConnectionHealth {
        let startTime = Date()
        let isReachable = await ping()
        let responseTime = Date().timeIntervalSince(startTime)
        
        return ConnectionHealth(
            isConnected: isReachable,
            quality: determineConnectionQuality(responseTime: responseTime, success: isReachable),
            responseTime: responseTime,
            lastSuccessfulConnection: lastSuccessfulConnection
        )
    }
    
    // MARK: - PRIVATE HELPERS (OPTIMIZED)
    
    private func updateConnectionState(responseTime: TimeInterval, success: Bool) {
        isConnected = success
        connectionQuality = determineConnectionQuality(responseTime: responseTime, success: success)
        
        if success {
            lastSuccessfulConnection = Date()
        }
    }
    
    private func determineConnectionQuality(responseTime: TimeInterval, success: Bool) -> ConnectionQuality {
        guard success else { return .timeout }
        guard responseTime > 0 else { return .unknown }
        
        switch responseTime {
        case 0..<0.5: return .excellent
        case 0.5..<1.5: return .good
        case 1.5..<5.0: return .poor
        default: return .poor  // Slow but connected
        }
    }
    
    private func validateEndpoint(_ endpoint: String) -> Bool {
        let allowedEndpoints = [
            "ping", "getArtists", "getArtist", "getAlbum", "getAlbumList2",
            "getCoverArt", "stream", "getGenres", "search2",
            "star", "unstar", "getStarred2"
        ]
        return allowedEndpoints.contains(endpoint) &&
               endpoint.allSatisfy { $0.isLetter || $0.isNumber }
    }
    
    private func validateParameter(key: String, value: String) -> Bool {
        guard key.count <= 50, value.count <= 1000 else { return false }
        
        // Only block real security risks, not genre characters
        let dangerousChars = CharacterSet(charactersIn: "<>\"'")
        return key.rangeOfCharacter(from: dangerousChars) == nil &&
               value.rangeOfCharacter(from: dangerousChars) == nil
    }
    
    private func generateSecureSalt() -> String {
        let saltLength = 12
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<saltLength).compactMap { _ in characters.randomElement() })
    }
}

// MARK: - Supporting Types

enum ConnectionTestResult {
    case success(ConnectionInfo)
    case failure(ConnectionError)
}

struct ConnectionInfo {
    let version: String
    let type: String
    let serverVersion: String
    let openSubsonic: Bool
}

enum ConnectionError {
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

struct ConnectionHealth {
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
