import Foundation

// FIX: Converted to Actor for consistency with UnifiedService
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
    
    // MARK: - Star/Unstar API
    
    func starSong(_ songId: String) async throws {
        guard !songId.isEmpty else { throw FavoritesError.invalidInput }
        
        guard let url = await connectionService.buildURL(endpoint: "star", params: ["id": songId]) else {
            throw SubsonicError.badURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else { throw SubsonicError.unknown }
            
            if httpResponse.statusCode != 200 {
                throw SubsonicError.server(statusCode: httpResponse.statusCode)
            }
            // Verify success by decoding
            _ = try JSONDecoder().decode(SubsonicResponse<EmptyResponse>.self, from: data)
        } catch {
            throw SubsonicError.from(error)
        }
    }
    
    func unstarSong(_ songId: String) async throws {
        guard !songId.isEmpty else { throw FavoritesError.invalidInput }
        
        guard let url = await connectionService.buildURL(endpoint: "unstar", params: ["id": songId]) else {
            throw SubsonicError.badURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else { throw SubsonicError.unknown }
            
            if httpResponse.statusCode != 200 {
                throw SubsonicError.server(statusCode: httpResponse.statusCode)
            }
            _ = try JSONDecoder().decode(SubsonicResponse<EmptyResponse>.self, from: data)
        } catch {
            throw SubsonicError.from(error)
        }
    }
    
    func getStarredSongs() async throws -> [Song] {
        guard let url = await connectionService.buildURL(endpoint: "getStarred2") else {
            throw SubsonicError.badURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else { throw SubsonicError.unknown }
            
            if httpResponse.statusCode == 200 {
                let decoded = try JSONDecoder().decode(SubsonicResponse<StarredContainer>.self, from: data)
                return decoded.subsonicResponse.starred2?.song ?? []
            } else if httpResponse.statusCode == 401 {
                throw SubsonicError.unauthorized
            } else {
                throw SubsonicError.server(statusCode: httpResponse.statusCode)
            }
        } catch {
            throw SubsonicError.from(error)
        }
    }
    
    func starSongs(_ songIds: [String]) async throws {
        guard !songIds.isEmpty else { return }
        for songId in songIds {
            try await starSong(songId)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    
    func unstarSongs(_ songIds: [String]) async throws {
        guard !songIds.isEmpty else { return }
        for songId in songIds {
            try await unstarSong(songId)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}

// MARK: - Supporting Types

// FIX: Added Sendable
struct StarredContainer: Codable, Sendable {
    let starred2: StarredContent?
}

struct StarredContent: Codable, Sendable {
    let song: [Song]?
    let album: [Album]?
    let artist: [Artist]?
}

// FIX: Added Sendable
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
