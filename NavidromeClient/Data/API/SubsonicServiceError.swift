import Foundation

// MARK: - SubsonicError (Domain Layer) - SINGLE SOURCE OF TRUTH

enum SubsonicError: Error, LocalizedError {
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
        case .badURL:
            return "Invalid URL."
        case .network(let err):
            return "Network error: \(err.localizedDescription)"
        case .server(let code):
            return "Server responded with status \(code)."
        case .decoding(let err):
            return "Failed to process data: \(err.localizedDescription)"
        case .unauthorized:
            return "Username or password is incorrect."
        case .emptyResponse(let endpoint):
            return "No data available for \(endpoint)."
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        case .invalidInput(let parameter):
            return "Invalid input for parameter: \(parameter)"
        case .timeout(let endpoint):
            return "Connection timeout for \(endpoint)."
        case .unknown:
            return "Unknown error."
        }
    }
    
    /// Prüft ob es sich um einen "leeren Response" Fehler handelt
    var isEmptyResponse: Bool {
        switch self {
        case .emptyResponse:
            return true
        case .decoding(let underlying):
            // Prüfe ob es ein keyNotFound für wichtige Keys ist
            if case DecodingError.keyNotFound(let key, _) = underlying {
                return ["album", "artist", "song", "genre", "albumList2", "artists", "genres", "searchResult2"].contains(key.stringValue)
            }
            return false
        default:
            return false
        }
    }
    
    /// Prüft ob es ein Offline-Error ist (inkl. Timeouts)
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
        case .timeout:
            return true
        default:
            return false
        }
    }
    
    /// Prüft ob der Fehler als "harmlos" betrachtet werden kann (für UI)
    var isRecoverable: Bool {
        switch self {
        case .emptyResponse, .decoding, .network, .rateLimited, .timeout:
            return true
        default:
            return false
        }
    }
}

// MARK: - Conversion Extension: SubsonicError → ConnectionError

extension SubsonicError {
    /// Konvertiert SubsonicError in UI-freundlichen ConnectionError
    /// Verwendet im ConnectionService für Connection-spezifische Flows
    var asConnectionError: ConnectionError {
        switch self {
        case .unauthorized:
            return .invalidCredentials
            
        case .timeout:
            return .timeout
            
        case .network(let underlying):
            // Prüfe ob underlying ein URLError ist
            if let urlError = underlying as? URLError {
                switch urlError.code {
                case .timedOut:
                    return .timeout
                case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
                    return .serverUnreachable
                case .notConnectedToInternet:
                    return .networkError("No internet connection")
                default:
                    return .networkError(urlError.localizedDescription)
                }
            }
            return .serverUnreachable
            
        case .server(let statusCode):
            if statusCode == 401 || statusCode == 403 {
                return .invalidCredentials
            }
            return .serverUnreachable
            
        case .decoding, .emptyResponse:
            return .invalidServerType
            
        case .badURL, .invalidInput:
            return .invalidURL
            
        case .rateLimited:
            return .networkError("Rate limited - please wait")
            
        case .unknown:
            return .networkError("Unknown error")
        }
    }
}

// MARK: - Error Factory: Generic Error → SubsonicError

extension SubsonicError {
    /// Factory method: Erstellt SubsonicError aus generic Error
    /// Verwendet in allen Services für konsistentes Error Handling
    static func from(_ error: Error) -> SubsonicError {
        // Falls es schon ein SubsonicError ist
        if let subsonicError = error as? SubsonicError {
            return subsonicError
        }
        
        // URLError mapping
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timeout(endpoint: "unknown")
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
                return .network(underlying: urlError)
            case .notConnectedToInternet:
                return .network(underlying: urlError)
            case .badURL:
                return .badURL
            default:
                return .network(underlying: urlError)
            }
        }
        
        // DecodingError
        if error is DecodingError {
            return .decoding(underlying: error)
        }
        
        // Fallback
        return .unknown
    }
}
