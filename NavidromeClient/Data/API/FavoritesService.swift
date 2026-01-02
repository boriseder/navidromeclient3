//
//  FavoritesService.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Compliance
//  - Fixed unused variable warnings
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
        
        // FIX: Use `_` to discard unused data
        let (_, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubsonicError.unknown
        }
        
        if httpResponse.statusCode == 200 {
            return
        } else {
            throw SubsonicError.server(statusCode: httpResponse.statusCode)
        }
    }
    
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
        
        // FIX: Use `_` to discard unused data
        let (_, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubsonicError.unknown
        }
        
        if httpResponse.statusCode == 200 {
            return
        } else {
            throw SubsonicError.server(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Get Starred Songs API
    
    func getStarredSongs() async throws -> [Song] {
        guard let url = connectionService.buildURL(endpoint: "getStarred2") else {
            throw SubsonicError.badURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubsonicError.unknown
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SubsonicError.server(statusCode: httpResponse.statusCode)
        }
        
        let decoded = try JSONDecoder().decode(SubsonicResponse<StarredContainer>.self, from: data)
        return decoded.subsonicResponse.starred2?.song ?? []
    }
    
    // MARK: - Batch Operations
    
    func unstarSongs(_ songIds: [String]) async throws {
        for id in songIds {
            try await unstarSong(id)
        }
    }
}

// MARK: - Local Models (Ensure these are present)

struct StarredContainer: Codable, Sendable {
    let starred2: StarredContent?
}

struct StarredContent: Codable, Sendable {
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
        case .invalidInput: return "Invalid Input"
        case .songNotFound: return "Song Not Found"
        case .serverError(let msg): return "Server Error: \(msg)"
        }
    }
}
