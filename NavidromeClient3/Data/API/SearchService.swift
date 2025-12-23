//
//  SearchService.swift - Search & Filtering Operations
//  NavidromeClient
//
//   FOCUSED: Search queries, filtering, result ranking
/*

import Foundation

@MainActor
class SearchService {
    private let connectionService: ConnectionService
    private let session: URLSession
    
    // Search state
    @Published private(set) var isSearching = false
    @Published private(set) var lastSearchQuery = ""
    
    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: -  PRIMARY SEARCH API
    
    func search(query: String, maxResults: Int = 50) async throws -> SearchResult {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SearchResult(artists: [], albums: [], songs: [])
        }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        lastSearchQuery = trimmedQuery
        isSearching = true
        defer { isSearching = false }
        
        let decoded: SubsonicResponse<SearchContainer> = try await fetchData(
            endpoint: "search2",
            params: ["query": trimmedQuery, "maxResults": "\(maxResults)"],
            type: SubsonicResponse<SearchContainer>.self
        )
        
        let result = SearchResult(
            artists: decoded.subsonicResponse.searchResult2.artist ?? [],
            albums: decoded.subsonicResponse.searchResult2.album ?? [],
            songs: decoded.subsonicResponse.searchResult2.song ?? []
        )
        
        AppLogger.general.info(" Search '\(trimmedQuery)': \(result.artists.count) artists, \(result.albums.count) albums, \(result.songs.count) songs")
        
        return result
    }
    
    // MARK: -  ADVANCED SEARCH
    
    func searchByCategory(
        query: String,
        category: SearchCategory,
        maxResults: Int = 50
    ) async throws -> SearchResult {
        
        let fullResults = try await search(query: query, maxResults: maxResults * 3)
        
        switch category {
        case .artists:
            return SearchResult(artists: fullResults.artists, albums: [], songs: [])
        case .albums:
            return SearchResult(artists: [], albums: fullResults.albums, songs: [])
        case .songs:
            return SearchResult(artists: [], albums: [], songs: fullResults.songs)
        case .all:
            return fullResults
        }
    }
    
    func searchWithFilters(
        query: String,
        filters: SearchFilters,
        maxResults: Int = 50
    ) async throws -> SearchResult {
        
        let baseResults = try await search(query: query, maxResults: maxResults * 2)
        
        return SearchResult(
            artists: filterArtists(baseResults.artists, with: filters),
            albums: filterAlbums(baseResults.albums, with: filters),
            songs: filterSongs(baseResults.songs, with: filters)
        )
    }
    
    // MARK: -  SEARCH SUGGESTIONS
    
    func getSearchSuggestions(for partialQuery: String, limit: Int = 5) async -> [String] {
        let query = partialQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }
        
        do {
            // Perform a small search to get suggestions
            let results = try await search(query: query, maxResults: 10)
            
            var suggestions: Set<String> = []
            
            // Extract suggestions from artist names
            for artist in results.artists.prefix(3) {
                if artist.name.lowercased().hasPrefix(query) {
                    suggestions.insert(artist.name)
                }
            }
            
            // Extract suggestions from album names
            for album in results.albums.prefix(3) {
                if album.name.lowercased().hasPrefix(query) {
                    suggestions.insert(album.name)
                }
                if album.artist.lowercased().hasPrefix(query) {
                    suggestions.insert(album.artist)
                }
            }
            
            return Array(suggestions.prefix(limit)).sorted()
            
        } catch {
            AppLogger.ui.error("❌ Failed to get search suggestions: \(error)")
            return []
        }
    }
    
    // MARK: -  SEARCH RANKING & SORTING
    
    func rankSearchResults(_ results: SearchResult, for query: String) -> SearchResult {
        let lowercaseQuery = query.lowercased()
        
        let rankedArtists = results.artists.sorted { a, b in
            let aStarts = a.name.lowercased().hasPrefix(lowercaseQuery)
            let bStarts = b.name.lowercased().hasPrefix(lowercaseQuery)
            
            if aStarts && !bStarts { return true }
            if !aStarts && bStarts { return false }
            return a.name < b.name
        }
        
        let rankedAlbums = results.albums.sorted { a, b in
            let aNameStarts = a.name.lowercased().hasPrefix(lowercaseQuery)
            let bNameStarts = b.name.lowercased().hasPrefix(lowercaseQuery)
            let aArtistStarts = a.artist.lowercased().hasPrefix(lowercaseQuery)
            let bArtistStarts = b.artist.lowercased().hasPrefix(lowercaseQuery)
            
            if aNameStarts && !bNameStarts { return true }
            if !aNameStarts && bNameStarts { return false }
            if aArtistStarts && !bArtistStarts { return true }
            if !aArtistStarts && bArtistStarts { return false }
            return a.name < b.name
        }
        
        let rankedSongs = results.songs.sorted { a, b in
            let aTitleStarts = a.title.lowercased().hasPrefix(lowercaseQuery)
            let bTitleStarts = b.title.lowercased().hasPrefix(lowercaseQuery)
            let aArtistStarts = (a.artist?.lowercased().hasPrefix(lowercaseQuery) ?? false)
            let bArtistStarts = (b.artist?.lowercased().hasPrefix(lowercaseQuery) ?? false)
            
            if aTitleStarts && !bTitleStarts { return true }
            if !aTitleStarts && bTitleStarts { return false }
            if aArtistStarts && !bArtistStarts { return true }
            if !aArtistStarts && bArtistStarts { return false }
            return a.title < b.title
        }
        
        return SearchResult(
            artists: rankedArtists,
            albums: rankedAlbums,
            songs: rankedSongs
        )
    }
    
    // MARK: -  FILTERING LOGIC
    
    private func filterArtists(_ artists: [Artist], with filters: SearchFilters) -> [Artist] {
        return artists.filter { artist in
            // Filter by minimum album count
            if let minAlbums = filters.minAlbumCount {
                if (artist.albumCount ?? 0) < minAlbums { return false }
            }
            
            return true
        }
    }
    
    private func filterAlbums(_ albums: [Album], with filters: SearchFilters) -> [Album] {
        return albums.filter { album in
            // Filter by year range
            if let yearRange = filters.yearRange, let albumYear = album.year {
                if albumYear < yearRange.lowerBound || albumYear > yearRange.upperBound {
                    return false
                }
            }
            
            // Filter by genre
            if let requiredGenre = filters.genre, let albumGenre = album.genre {
                if !albumGenre.lowercased().contains(requiredGenre.lowercased()) {
                    return false
                }
            }
            
            return true
        }
    }
    
    private func filterSongs(_ songs: [Song], with filters: SearchFilters) -> [Song] {
        return songs.filter { song in
            // Filter by duration range
            if let durationRange = filters.durationRange, let songDuration = song.duration {
                if songDuration < durationRange.lowerBound || songDuration > durationRange.upperBound {
                    return false
                }
            }
            
            // Filter by year range
            if let yearRange = filters.yearRange, let songYear = song.year {
                if songYear < yearRange.lowerBound || songYear > yearRange.upperBound {
                    return false
                }
            }
            
            return true
        }
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
    
    // MARK: -  SEARCH STATE ACCESS
    
    var currentSearchQuery: String {
        return lastSearchQuery
    }
}

// MARK: -  SUPPORTING TYPES

enum SearchCategory {
    case all
    case artists
    case albums
    case songs
}

struct SearchFilters {
    let yearRange: ClosedRange<Int>?
    let genre: String?
    let minAlbumCount: Int?
    let durationRange: ClosedRange<Int>? // in seconds
    
    static let empty = SearchFilters(
        yearRange: nil,
        genre: nil,
        minAlbumCount: nil,
        durationRange: nil
    )
}
*/
