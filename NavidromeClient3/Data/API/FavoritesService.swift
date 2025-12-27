import Foundation

actor FavoritesService {
    private let connectionService: ConnectionService
    
    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
    }
    
    func starSong(_ songId: String) async throws {
        guard let url = await connectionService.buildURL(endpoint: "star", params: ["id": songId]) else {
            throw SubsonicError.badURL
        }
        _ = try await connectionService.getData(from: url)
    }
    
    func unstarSong(_ songId: String) async throws {
        guard let url = await connectionService.buildURL(endpoint: "unstar", params: ["id": songId]) else {
            throw SubsonicError.badURL
        }
        _ = try await connectionService.getData(from: url)
    }
    
    func getStarredSongs() async throws -> [Song] {
        guard let url = await connectionService.buildURL(endpoint: "getStarred2") else {
            throw SubsonicError.badURL
        }
        let (data, _) = try await connectionService.getData(from: url)
        
        let decoded = try JSONDecoder().decode(SubsonicResponse<StarredContainer>.self, from: data)
        return decoded.subsonicResponse.starred2?.song ?? []
    }
}

// FIX: Added Sendable conformance
struct StarredContainer: Codable, Sendable {
    let starred2: StarredContent?
}

// FIX: Added Sendable conformance
struct StarredContent: Codable, Sendable {
    let song: [Song]?
    let album: [Album]?
    let artist: [Artist]?
}
