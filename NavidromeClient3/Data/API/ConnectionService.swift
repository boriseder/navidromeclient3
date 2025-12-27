import Foundation
import CryptoKit
import OSLog

// MARK: - Types (Must be outside Actor)
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

enum ConnectionError: Error, Sendable {
    case invalidCredentials
    case serverUnreachable
    case timeout
    case networkError(String)
    case invalidServerType
    case invalidURL
    
    var userMessage: String {
        switch self {
        case .invalidCredentials: return "Invalid username or password"
        case .serverUnreachable: return "Server unreachable"
        case .timeout: return "Connection timeout"
        case .networkError(let msg): return "Network error: \(msg)"
        case .invalidServerType: return "Invalid server response"
        case .invalidURL: return "Invalid server URL"
        }
    }
}

actor ConnectionService {
    private let baseURL: URL
    private let username: String
    private let password: String
    private let session: URLSession
    
    // Internal State
    private var _isConnected = false
    private var _connectionQuality: ConnectionQuality = .unknown
    private var _lastSuccessfulConnection: Date?

    enum ConnectionQuality: Sendable {
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

    init(baseURL: URL, username: String, password: String) {
        self.baseURL = baseURL
        self.username = username
        self.password = password
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public API
    
    func getConnectionState() -> (isConnected: Bool, quality: ConnectionQuality, lastSuccess: Date?) {
        return (_isConnected, _connectionQuality, _lastSuccessfulConnection)
    }
    
    func testConnection() async -> ConnectionTestResult {
        guard let url = buildURL(endpoint: "ping") else { return .failure(.invalidURL) }
        
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .failure(.serverUnreachable)
            }
            
            // PingInfo is now Sendable (from GenericModel.swift), so this works
            let decoded = try JSONDecoder().decode(SubsonicResponse<PingInfo>.self, from: data)
            
            updateConnectionState(success: true)
            
            return .success(ConnectionInfo(
                version: decoded.subsonicResponse.version,
                type: decoded.subsonicResponse.type,
                serverVersion: decoded.subsonicResponse.serverVersion,
                openSubsonic: decoded.subsonicResponse.openSubsonic
            ))
            
        } catch {
            updateConnectionState(success: false)
            return .failure(.networkError(error.localizedDescription))
        }
    }
    
    func ping() async -> Bool {
        guard let url = buildURL(endpoint: "ping") else { return false }
        do {
            let (_, response) = try await session.data(from: url)
            let success = (response as? HTTPURLResponse)?.statusCode == 200
            updateConnectionState(success: success)
            return success
        } catch {
            return false
        }
    }

    // MARK: - Helper Methods
    
    func buildURL(endpoint: String, params: [String: String] = [:]) -> URL? {
        guard var components = URLComponents(string: baseURL.absoluteString) else { return nil }
        components.path = "/rest/\(endpoint).view"
        
        // FIX: Now calls the nonisolated extensions safely
        let salt = String.randomAlphaNumeric(length: 12)
        let token = (password + salt).md5()
        
        var queryItems = [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "NavidromeClient"),
            URLQueryItem(name: "f", value: "json")
        ]
        
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        components.queryItems = queryItems
        return components.url
    }
    
    func getData(from url: URL) async throws -> (Data, URLResponse) {
        return try await session.data(from: url)
    }
    
    private func updateConnectionState(success: Bool) {
        _isConnected = success
        if success { _lastSuccessfulConnection = Date() }
    }
}

// MARK: - Extensions (FIX: nonisolated)

extension String {
    // FIX: Marked nonisolated so the Actor can call it synchronously
    nonisolated func md5() -> String {
        let digest = Insecure.MD5.hash(data: Data(self.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    // FIX: Marked nonisolated
    nonisolated static func randomAlphaNumeric(length: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }
}
