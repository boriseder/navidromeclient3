//
//  SubsonicServiceError.swift
//  NavidromeClient
//
//  UPDATED: Sendable Conformance
//

import Foundation

enum SubsonicError: Error, LocalizedError, Sendable {
    case badURL
    case network(underlying: Error)
    case server(statusCode: Int)
    case decoding(underlying: Error)
    case unauthorized
    case unknown
    case emptyResponse(endpoint: String)
    case rateLimited
    case invalidInput(parameter: String)
    case timeout(endpoint: String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid URL."
        case .network(let err): return "Network error: \(err.localizedDescription)"
        case .server(let code): return "Server responded with status \(code)."
        case .decoding(let err): return "Failed to process data: \(err.localizedDescription)"
        case .unauthorized: return "Username or password is incorrect."
        case .emptyResponse(let endpoint): return "No data available for \(endpoint)."
        case .rateLimited: return "Too many requests. Please wait a moment."
        case .invalidInput(let parameter): return "Invalid input for parameter: \(parameter)"
        case .timeout(let endpoint): return "Connection timeout for \(endpoint)."
        case .unknown: return "Unknown error."
        }
    }
    
    var isEmptyResponse: Bool {
        switch self {
        case .emptyResponse: return true
        case .decoding(let underlying):
            if case DecodingError.keyNotFound(let key, _) = underlying {
                return ["album", "artist", "song", "genre", "albumList2", "artists", "genres", "searchResult2"].contains(key.stringValue)
            }
            return false
        default: return false
        }
    }
    
    var isOfflineError: Bool {
        switch self {
        case .network(let error):
            if let urlError = error as? URLError {
                return urlError.code == .notConnectedToInternet ||
                       urlError.code == .timedOut ||
                       urlError.code == .cannotConnectToHost ||
                       urlError.code == .networkConnectionLost ||
                       urlError.code == .cannotFindHost
            }
            return false
        case .timeout: return true
        default: return false
        }
    }
}

// Ensure extensions handle Sendable properly
extension SubsonicError {
    var asConnectionError: ConnectionError {
        switch self {
        case .unauthorized: return .invalidCredentials
        case .timeout: return .timeout
        case .network(let underlying):
            if let urlError = underlying as? URLError {
                switch urlError.code {
                case .timedOut: return .timeout
                case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost: return .serverUnreachable
                case .notConnectedToInternet: return .networkError("No internet connection")
                default: return .networkError(urlError.localizedDescription)
                }
            }
            return .serverUnreachable
        case .server(let statusCode):
            return (statusCode == 401 || statusCode == 403) ? .invalidCredentials : .serverUnreachable
        case .decoding, .emptyResponse: return .invalidServerType
        case .badURL, .invalidInput: return .invalidURL
        case .rateLimited: return .networkError("Rate limited - please wait")
        case .unknown: return .networkError("Unknown error")
        }
    }
    
    static func from(_ error: Error) -> SubsonicError {
        if let subsonicError = error as? SubsonicError { return subsonicError }
        if let urlError = error as? URLError {
            if urlError.code == .timedOut { return .timeout(endpoint: "unknown") }
            return .network(underlying: urlError)
        }
        if error is DecodingError { return .decoding(underlying: error) }
        return .unknown
    }
}
