//
//  FavoritesService.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Marked @MainActor
//

import Foundation

final class FavoritesService: Sendable {

    private let network: NetworkActor

    init(network: NetworkActor) {
        self.network = network
    }

    func starSong(_ songId: String) async throws {
        guard !songId.isEmpty else { throw FavoritesError.invalidInput }
        let _: SubsonicResponse<EmptyResponse> = try await network.fetchData(
            endpoint: "star", params: ["id": songId]
        )
    }

    func unstarSong(_ songId: String) async throws {
        guard !songId.isEmpty else { throw FavoritesError.invalidInput }
        let _: SubsonicResponse<EmptyResponse> = try await network.fetchData(
            endpoint: "unstar", params: ["id": songId]
        )
    }

    func getStarredSongs() async throws -> [Song] {
        let decoded: SubsonicResponse<StarredContainer> = try await network.fetchData(
            endpoint: "getStarred2"
        )
        return decoded.subsonicResponse.starred2?.song ?? []
    }

    func starSongs(_ ids: [String]) async throws {
        for id in ids {
            try await starSong(id)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    func unstarSongs(_ ids: [String]) async throws {
        for id in ids {
            try await unstarSong(id)
            try? await Task.sleep(nanoseconds: 100_000_000)
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
