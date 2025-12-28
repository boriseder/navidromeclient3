import Foundation

// Enum is Global and Sendable
enum AlbumSortType: String, CaseIterable, Sendable {
    case alphabetical = "alphabeticalByName"
    case alphabeticalByArtist = "alphabeticalByArtist"
    case newest = "newest"
    case recent = "recent"
    case frequent = "frequent"
    case random = "random"
    case byYear = "byYear"
    case byGenre = "byGenre"
    
    var displayName: String {
        switch self {
        case .alphabetical: return "A-Z (Name)"
        case .alphabeticalByArtist: return "A-Z (Artist)"
        case .newest: return "Newest"
        case .recent: return "Recently Played"
        case .frequent: return "Most Played"
        case .random: return "Random"
        case .byYear: return "By Year"
        case .byGenre: return "By Genre"
        }
    }
    
    var icon: String {
        switch self {
        case .alphabetical, .alphabeticalByArtist: return "textformat.abc"
        case .newest: return "sparkles"
        case .recent: return "clock"
        case .frequent: return "chart.bar"
        case .random: return "shuffle"
        case .byYear: return "calendar"
        case .byGenre: return "music.note.list"
        }
    }
}

actor ContentService {
    private let connectionService: ConnectionService
    private let session: URLSession
    
    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    func getAllAlbums(
        sortBy: AlbumSortType = .alphabetical,
        size: Int = 500,
        offset: Int = 0
    ) async throws -> [Album] {
        let params = [
            "type": sortBy.rawValue,
            "size": "\(size)",
            "offset": "\(offset)"
        ]
        
        let decoded: SubsonicResponse<AlbumListContainer> = try await fetchData(
            endpoint: "getAlbumList2",
            params: params
        )
        return decoded.subsonicResponse.albumList2.album
    }
    
    func getAlbumsByArtist(artistId: String) async throws -> [Album] {
        guard !artistId.isEmpty else { return [] }
        
        let decoded: SubsonicResponse<ArtistDetailContainer> = try await fetchData(
            endpoint: "getArtist",
            params: ["id": artistId]
        )
        return decoded.subsonicResponse.artist.album ?? []
    }
    
    func getAlbumsByGenre(size: Int = 500, genre: String) async throws -> [Album] {
        guard !genre.isEmpty else { return [] }
        
        let params = ["size": "\(size)", "type": "byGenre", "genre": genre]
        
        let decoded: SubsonicResponse<AlbumListContainer> = try await fetchData(
            endpoint: "getAlbumList2",
            params: params
        )
        return decoded.subsonicResponse.albumList2.album
    }
    
    func getArtists() async throws -> [Artist] {
        let decoded: SubsonicResponse<ArtistsContainer> = try await fetchData(endpoint: "getArtists")
        return decoded.subsonicResponse.artists?.index?.flatMap { $0.artist ?? [] } ?? []
    }
    
    func getSongs(for albumId: String) async throws -> [Song] {
        guard !albumId.isEmpty else { return [] }
        
        let decoded: SubsonicResponse<AlbumWithSongsContainer> = try await fetchData(
            endpoint: "getAlbum",
            params: ["id": albumId]
        )
        return decoded.subsonicResponse.album.song ?? []
    }
    
    func getGenres() async throws -> [Genre] {
        let decoded: SubsonicResponse<GenresContainer> = try await fetchData(endpoint: "getGenres")
        return decoded.subsonicResponse.genres?.genre ?? []
    }
    
    private func fetchData<T: Decodable & Sendable>(
        endpoint: String,
        params: [String: String] = [:]
    ) async throws -> T {
        
        guard let url = await connectionService.buildURL(endpoint: endpoint, params: params) else {
            throw SubsonicError.badURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubsonicError.unknown
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(T.self, from: data)
        } else if httpResponse.statusCode == 401 {
            throw SubsonicError.unauthorized
        } else {
            throw SubsonicError.server(statusCode: httpResponse.statusCode)
        }
    }
}
