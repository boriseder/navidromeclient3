//
//  DiscoveryService.swift - Home Screen & Recommendations
//  NavidromeClient
//
//   FOCUSED: Recent, newest, frequent, random albums - discovery content
//

import Foundation

@MainActor
class DiscoveryService {
    private let connectionService: ConnectionService
    private let session: URLSession
    
    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: -  DISCOVERY ALGORITHMS
    
    func getRecentAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: .recent, size: size)
    }
    
    func getNewestAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: .newest, size: size)
    }
    
    func getFrequentAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: .frequent, size: size)
    }
    
    func getRandomAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: .random, size: size)
    }
    
    // MARK: -  ADVANCED DISCOVERY
    
    func getRecommendationsFor(artist: Artist, limit: Int = 10) async throws -> [Album] {
        // Get albums by same artist
        let sameArtistAlbums = try await getSimilarByArtist(artistId: artist.id, limit: limit / 2)
        
        // Get albums from same genre (if available)
        var genreAlbums: [Album] = []
        if sameArtistAlbums.count < limit {
            genreAlbums = try await getSimilarByGenre(
                from: sameArtistAlbums.first,
                limit: limit - sameArtistAlbums.count
            )
        }
        
        return Array((sameArtistAlbums + genreAlbums).prefix(limit))
    }
    
    func getRecommendationsFor(album: Album, limit: Int = 10) async throws -> [Album] {
        // Get other albums by same artist
        let sameArtistAlbums = try await getSimilarByArtist(artistId: album.artistId, limit: limit / 2)
            .filter { $0.id != album.id } // Exclude the current album
        
        // Get albums from same genre
        var genreAlbums: [Album] = []
        if sameArtistAlbums.count < limit {
            genreAlbums = try await getSimilarByGenre(
                from: album,
                limit: limit - sameArtistAlbums.count
            )
        }
        
        return Array((sameArtistAlbums + genreAlbums).prefix(limit))
    }
    
    func getDiscoveryMix(size: Int = 20) async throws -> DiscoveryMix {
        // Load different discovery categories in parallel
        async let recent = getRecentAlbums(size: size / 4)
        async let newest = getNewestAlbums(size: size / 4)
        async let frequent = getFrequentAlbums(size: size / 4)
        async let random = getRandomAlbums(size: size / 4)
        
        return try await DiscoveryMix(
            recent: recent,
            newest: newest,
            frequent: frequent,
            random: random
        )
    }
    
    // MARK: -  GENRE-BASED DISCOVERY
    
    func getAlbumsByGenre(genre: String, limit: Int = 20) async throws -> [Album] {
        guard !genre.isEmpty else { return [] }
        
        let decoded: SubsonicResponse<AlbumListContainer> = try await fetchData(
            endpoint: "getAlbumList2",
            params: ["type": "byGenre", "genre": genre, "size": "\(limit)"],
            type: SubsonicResponse<AlbumListContainer>.self
        )
        
        return decoded.subsonicResponse.albumList2.album
    }
    
    func getPopularGenres(limit: Int = 10) async throws -> [GenreWithAlbumCount] {
        let decoded: SubsonicResponse<GenresContainer> = try await fetchData(
            endpoint: "getGenres",
            type: SubsonicResponse<GenresContainer>.self
        )
        
        let genres = decoded.subsonicResponse.genres?.genre ?? []
        
        // Sort by album count and take top genres
        return genres
            .map { GenreWithAlbumCount(genre: $0.value, albumCount: $0.albumCount) }
            .sorted { $0.albumCount > $1.albumCount }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: -  TIME-BASED DISCOVERY
    
    func getAlbumsFromYear(year: Int, limit: Int = 20) async throws -> [Album] {
        // This would need a custom implementation or use search
        return try await getAlbumList(type: .byYear, size: limit)
            .filter { $0.year == year }
    }
    
    func getAlbumsFromDecade(decade: Int, limit: Int = 20) async throws -> [Album] {
        let startYear = decade
        let endYear = decade + 9
        
        return try await getAlbumList(type: .byYear, size: limit * 2)
            .filter { album in
                if let year = album.year {
                    return year >= startYear && year <= endYear
                }
                return false
            }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: -  PRIVATE CORE METHODS
    
    private func getAlbumList(type: AlbumListType, size: Int = 20, offset: Int = 0) async throws -> [Album] {
        let params = ["type": type.rawValue, "size": "\(size)", "offset": "\(offset)"]
        
        // Create fallback for empty responses
        let emptyAlbumList = AlbumList(album: [])
        let emptyContainer = AlbumListContainer(albumList2: emptyAlbumList)
        let fallbackResponse = SubsonicResponse<AlbumListContainer>(subsonicResponse: emptyContainer)
        
        let decoded: SubsonicResponse<AlbumListContainer> = try await fetchDataWithFallback(
            endpoint: "getAlbumList2",
            params: params,
            type: SubsonicResponse<AlbumListContainer>.self,
            fallback: fallbackResponse
        )
        
        let albums = decoded.subsonicResponse.albumList2.album
        AppLogger.general.info(" Loaded \(albums.count) \(type.rawValue) albums")
        return albums
    }
    
    private func getSimilarByArtist(artistId: String?, limit: Int) async throws -> [Album] {
        guard let artistId = artistId, !artistId.isEmpty else { return [] }
        
        let decoded: SubsonicResponse<ArtistDetailContainer> = try await fetchData(
            endpoint: "getArtist",
            params: ["id": artistId],
            type: SubsonicResponse<ArtistDetailContainer>.self
        )
        
        return Array((decoded.subsonicResponse.artist.album ?? []).prefix(limit))
    }
    
    private func getSimilarByGenre(from album: Album?, limit: Int) async throws -> [Album] {
        guard let album = album, let genre = album.genre, !genre.isEmpty else { return [] }
        
        return try await getAlbumsByGenre(genre: genre, limit: limit)
            .filter { $0.id != album.id } // Exclude the source album
    }
    
    // MARK: -  CORE FETCH IMPLEMENTATION
    
    private func fetchData<T: Decodable>(
        endpoint: String,
        params: [String: String] = [:],
        type: T.Type
    ) async throws -> T {
        
        guard let url = connectionService.buildURL(endpoint: endpoint, params: params) else {
            throw SubsonicError.badURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubsonicError.unknown
            }
            
            switch httpResponse.statusCode {
            case 200:
                return try JSONDecoder().decode(T.self, from: data)
            case 401:
                throw SubsonicError.unauthorized
            case 429:
                throw SubsonicError.rateLimited
            case 500...599:
                throw SubsonicError.server(statusCode: httpResponse.statusCode)
            default:
                throw SubsonicError.server(statusCode: httpResponse.statusCode)
            }
        } catch {
            if error is SubsonicError {
                throw error
            } else {
                if let urlError = error as? URLError, urlError.code == .timedOut {
                    throw SubsonicError.timeout(endpoint: endpoint)
                }
                throw SubsonicError.network(underlying: error)
            }
        }
    }
    
    private func fetchDataWithFallback<T: Decodable>(
        endpoint: String,
        params: [String: String] = [:],
        type: T.Type,
        fallback: T
    ) async throws -> T {
        do {
            return try await fetchData(endpoint: endpoint, params: params, type: type)
        } catch {
            // Handle empty response decoding errors
            if let subsonicError = error as? SubsonicError, subsonicError.isEmptyResponse {
                return fallback
            }
            
            if case DecodingError.keyNotFound(let key, _) = error {
                let emptyResponseKeys = ["albumList2", "artists", "genres"]
                if emptyResponseKeys.contains(key.stringValue) {
                    return fallback
                }
            }
            
            throw error
        }
    }
}

// MARK: -  SUPPORTING TYPES

extension DiscoveryService {
    enum AlbumListType: String {
        case recent = "recent"
        case newest = "newest"
        case frequent = "frequent"
        case random = "random"
        case byGenre = "byGenre"
        case byYear = "byYear"
    }
}

struct DiscoveryMix {
    let recent: [Album]
    let newest: [Album]
    let frequent: [Album]
    let random: [Album]
    
    var allAlbums: [Album] {
        return recent + newest + frequent + random
    }
    
    var totalCount: Int {
        return recent.count + newest.count + frequent.count + random.count
    }
    
    var isEmpty: Bool {
        return totalCount == 0
    }
}

struct GenreWithAlbumCount {
    let genre: String
    let albumCount: Int
}
