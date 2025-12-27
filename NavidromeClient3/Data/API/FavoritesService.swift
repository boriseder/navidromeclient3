//
//  FavoritesService.swift
//  NavidromeClient
//
//  Fixed: Ensures all return types are Sendable
//

import Foundation

actor FavoritesService {
    private let connectionService: ConnectionService
    private let session: URLSession
    
    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    func starSong(_ songId: String) async throws {
        guard !songId.isEmpty else { throw FavoritesError.invalidInput }
        
        guard let url = await connectionService.buildURL(endpoint: "star", params: ["id": songId]) else {
            throw SubsonicError.badURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SubsonicError.server(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        _ = try JSONDecoder().decode(SubsonicResponse<EmptyResponse>.self, from: data)
    }
    
    func unstarSong(_ songId: String) async throws {
        guard !songId.isEmpty else { throw FavoritesError.invalidInput }
        
        guard let url = await connectionService.buildURL(endpoint: "unstar", params: ["id": songId]) else {
            throw SubsonicError.badURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SubsonicError.server(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        _ = try JSONDecoder().decode(SubsonicResponse<EmptyResponse>.self, from: data)
    }
    
    func getStarredSongs() async throws -> [Song] {
        guard let url = await connectionService.buildURL(endpoint: "getStarred2") else {
            throw SubsonicError.badURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SubsonicError.server(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        let decoded = try JSONDecoder().decode(SubsonicResponse<StarredContainer>.self, from: data)
        return decoded.subsonicResponse.starred2?.song ?? []
    }
    
    func starSongs(_ songIds: [String]) async throws {
        for songId in songIds {
            try await starSong(songId)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    
    func unstarSongs(_ songIds: [String]) async throws {
        for songId in songIds {
            try await unstarSong(songId)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}

// MARK: - Supporting Types
// These MUST be Sendable for Actor return types
struct StarredContainer: Codable, Sendable {
    let starred2: StarredContent?
}

struct StarredContent: Codable, Sendable {
    let song: [Song]?
    let album: [Album]?
    let artist: [Artist]?
}

enum FavoritesError: LocalizedError, Sendable {
    case invalidInput
    case songNotFound
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput: return "Invalid song ID provided"
        case .songNotFound: return "Song not found on server"
        case .serverError(let message): return "Server error: \(message)"
        }
    }
}
