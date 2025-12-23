//
//  ContentService.swift
//  NavidromeClient
//
//  Created by Boris Eder on 16.09.25.
//


//
//  ContentService.swift - Library Content Operations  
//  NavidromeClient
//
//   FOCUSED: Albums, artists, songs, genres - all library content
//

import Foundation

@MainActor  
class ContentService {
    private let connectionService: ConnectionService
    private let session: URLSession
    
    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: -  ALBUMS API
    
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
            params: params,
            type: SubsonicResponse<AlbumListContainer>.self
        )
        
        return decoded.subsonicResponse.albumList2.album
    }
    
    func getAlbumsByArtist(artistId: String) async throws -> [Album] {
        guard !artistId.isEmpty else { return [] }
        
        let decoded: SubsonicResponse<ArtistDetailContainer> = try await fetchData(
            endpoint: "getArtist",
            params: ["id": artistId],
            type: SubsonicResponse<ArtistDetailContainer>.self
        )
        
        return decoded.subsonicResponse.artist.album ?? []
    }
    
    func getAlbumsByGenre(
        size: Int = 500,
        genre: String
    ) async throws -> [Album] {

        guard !genre.isEmpty else { return [] }
        
        let params = [
            "size": "\(size)",
            "type": "byGenre",
            "genre": genre]
        
        do {
            let decoded: SubsonicResponse<AlbumListContainer> = try await fetchData(
                endpoint: "getAlbumList2",
                params: params,
                type: SubsonicResponse<AlbumListContainer>.self
            )
            
            let albums = decoded.subsonicResponse.albumList2.album
            return albums
            
        } catch {
            AppLogger.ui.error("❌ getAlbumsByGenre failed with error: \(error)")
            
            // Fallback: Test mit fetchDataWithFallback
            AppLogger.general.debug(" DEBUG: Trying fallback method...")
            
            let emptyAlbumList = AlbumList(album: [])
            let emptyContainer = AlbumListContainer(albumList2: emptyAlbumList)
            let fallbackResponse = SubsonicResponse<AlbumListContainer>(subsonicResponse: emptyContainer)
            
            let result = try await fetchDataWithFallback(
                endpoint: "getAlbumList2",
                params: params,
                type: SubsonicResponse<AlbumListContainer>.self,
                fallback: fallbackResponse
            )
            return result.subsonicResponse.albumList2.album

        }
    }
    
    // MARK: -  ARTISTS API
    
    func getArtists() async throws -> [Artist] {
        let decoded: SubsonicResponse<ArtistsContainer> = try await fetchData(
            endpoint: "getArtists",
            type: SubsonicResponse<ArtistsContainer>.self
        )
        
        return decoded.subsonicResponse.artists?.index?.flatMap { $0.artist ?? [] } ?? []
    }
    
    // MARK: -  SONGS API
    
    func getSongs(for albumId: String) async throws -> [Song] {
        guard !albumId.isEmpty else { return [] }
        
        let decoded: SubsonicResponse<AlbumWithSongsContainer> = try await fetchData(
            endpoint: "getAlbum",
            params: ["id": albumId],
            type: SubsonicResponse<AlbumWithSongsContainer>.self
        )
        
        return decoded.subsonicResponse.album.song ?? []
    }
    
    // MARK: -  GENRES API
    
    func getGenres() async throws -> [Genre] {
        let decoded: SubsonicResponse<GenresContainer> = try await fetchData(
            endpoint: "getGenres",
            type: SubsonicResponse<GenresContainer>.self
        )
        
        return decoded.subsonicResponse.genres?.genre ?? []
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
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch let decodingError {
                    throw handleDecodingError(decodingError, endpoint: endpoint)
                }
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
    
    // MARK: -  BATCH OPERATIONS with Fallbacks
    
    func fetchDataWithFallback<T: Decodable>(
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
            
            // Handle keyNotFound specifically for known empty response keys
            if case DecodingError.keyNotFound(let key, _) = error {
                let emptyResponseKeys = ["albumList2", "artists", "genres", "album"]
                if emptyResponseKeys.contains(key.stringValue) {
                    return fallback
                }
            }
            
            throw error
        }
    }
    
    // MARK: -  ERROR HANDLING
    
    private func handleDecodingError(_ error: Error, endpoint: String) -> SubsonicError {
        if case DecodingError.keyNotFound(let key, _) = error {
            // Known "empty response" scenarios
            let emptyResponseKeys = ["album", "artist", "song", "genre"]
            if emptyResponseKeys.contains(key.stringValue) {
                return SubsonicError.emptyResponse(endpoint: endpoint)
            }
        }
        
        return SubsonicError.decoding(underlying: error)
    }
}

// MARK: -  ALBUM SORT TYPES

extension ContentService {
    enum AlbumSortType: String, CaseIterable {
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
}
