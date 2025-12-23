//
//  FavoritesService.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//

import Foundation

@MainActor
class FavoritesService {
    private let connectionService: ConnectionService
    private let session: URLSession
    
    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Star/Unstar API
    
    /// Markiert einen Song als Favorit (star)
    func starSong(_ songId: String) async throws {
        guard !songId.isEmpty else {
            throw FavoritesError.invalidInput
        }
        
        guard let url = connectionService.buildURL(
            endpoint: "star",
            params: ["id": songId]
        ) else {
            throw SubsonicError.badURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubsonicError.unknown
            }
            
            switch httpResponse.statusCode {
            case 200:
                // Parse response to verify success
                let decoded = try JSONDecoder().decode(SubsonicResponse<EmptyResponse>.self, from: data)
                
            case 401:
                throw SubsonicError.unauthorized
            case 404:
                throw FavoritesError.songNotFound
            default:
                throw SubsonicError.server(statusCode: httpResponse.statusCode)
            }
        } catch {
            if error is SubsonicError || error is FavoritesError {
                throw error
            } else {
                throw SubsonicError.network(underlying: error)
            }
        }
    }
    
    /// Entfernt Favorit-Markierung von einem Song (unstar)
    func unstarSong(_ songId: String) async throws {
        guard !songId.isEmpty else {
            throw FavoritesError.invalidInput
        }
        
        guard let url = connectionService.buildURL(
            endpoint: "unstar",
            params: ["id": songId]
        ) else {
            throw SubsonicError.badURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubsonicError.unknown
            }
            
            switch httpResponse.statusCode {
            case 200:
                // Parse response to verify success
                let decoded = try JSONDecoder().decode(SubsonicResponse<EmptyResponse>.self, from: data)
            case 401:
                throw SubsonicError.unauthorized
            case 404:
                throw FavoritesError.songNotFound
            default:
                throw SubsonicError.server(statusCode: httpResponse.statusCode)
            }
        } catch {
            if error is SubsonicError || error is FavoritesError {
                throw error
            } else {
                throw SubsonicError.network(underlying: error)
            }
        }
    }
    
    // MARK: - Get Starred Songs API
    
    /// Lädt alle favorisierten Songs vom Server
    func getStarredSongs() async throws -> [Song] {
        guard let url = connectionService.buildURL(endpoint: "getStarred2") else {
            throw SubsonicError.badURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubsonicError.unknown
            }
            
            switch httpResponse.statusCode {
            case 200:
                
                let decoded = try JSONDecoder().decode(SubsonicResponse<StarredContainer>.self, from: data)
                let songs = decoded.subsonicResponse.starred2?.song ?? []
                                
                return songs
                
            case 401:
                throw SubsonicError.unauthorized
            default:
                throw SubsonicError.server(statusCode: httpResponse.statusCode)
            }
        } catch {
            if error is SubsonicError {
                throw error
            } else {
                if let urlError = error as? URLError, urlError.code == .timedOut {
                    throw SubsonicError.timeout(endpoint: "getStarred2")
                }
                throw SubsonicError.network(underlying: error)
            }
        }
    }
    
    // MARK: - Batch Operations
    
    /// Markiert mehrere Songs gleichzeitig als Favorit
    func starSongs(_ songIds: [String]) async throws {
        guard !songIds.isEmpty else { return }
        
        for songId in songIds {
            try await starSong(songId)
            // Kurze Pause um Server nicht zu überlasten
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
    }
    
    /// Entfernt Favorit-Markierung von mehreren Songs
    func unstarSongs(_ songIds: [String]) async throws {
        guard !songIds.isEmpty else { return }
        
        for songId in songIds {
            try await unstarSong(songId)
            // Kurze Pause um Server nicht zu überlasten
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
    }
}

// MARK: - Supporting Types

struct StarredContainer: Codable {
    let starred2: StarredContent?
}

struct StarredContent: Codable {
    let song: [Song]?
    let album: [Album]?
    let artist: [Artist]?
}

enum FavoritesError: LocalizedError {
    case invalidInput
    case songNotFound
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid song ID provided"
        case .songNotFound:
            return "Song not found on server"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
