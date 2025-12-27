//
//  SearchService.swift - Search & Filtering Operations
//  NavidromeClient
//
//   FOCUSED: Search queries, filtering, result ranking
/*

 //
 //  SearchService.swift
 //  NavidromeClient
 //
 //  Swift 6: Converted to Actor
 //

 import Foundation

 actor SearchService {
     private let connectionService: ConnectionService
     private let session: URLSession
     
     // Search state is now returned to the caller, not stored in @Published
     // This allows the View/ViewModel to own the state (Source of Truth)
     
     init(connectionService: ConnectionService) {
         self.connectionService = connectionService
         
         let config = URLSessionConfiguration.default
         config.timeoutIntervalForRequest = 10
         config.timeoutIntervalForResource = 30
         self.session = URLSession(configuration: config)
     }
     
     // MARK: -  PRIMARY SEARCH API
     
     func search(query: String, maxResults: Int = 50) async throws -> SearchResult {
         let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
         guard !trimmedQuery.isEmpty else {
             return SearchResult(artists: [], albums: [], songs: [])
         }
         
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
         
         AppLogger.general.info("🔍 Search '\(trimmedQuery)': \(result.artists.count) artists, \(result.albums.count) albums")
         
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
     
     // MARK: -  SEARCH SUGGESTIONS
     
     func getSearchSuggestions(for partialQuery: String, limit: Int = 5) async -> [String] {
         let query = partialQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
         guard query.count >= 2 else { return [] }
         
         do {
             // Perform a small search
             let results = try await search(query: query, maxResults: 10)
             
             var suggestions: Set<String> = []
             
             // Extract suggestions logic (pure data processing is safe in Actor)
             for artist in results.artists.prefix(3) {
                 if artist.name.lowercased().hasPrefix(query) {
                     suggestions.insert(artist.name)
                 }
             }
             
             for album in results.albums.prefix(3) {
                 if album.name.lowercased().hasPrefix(query) {
                     suggestions.insert(album.name)
                 }
             }
             
             return Array(suggestions.prefix(limit)).sorted()
             
         } catch {
             return []
         }
     }
     
     // MARK: -  CORE FETCH IMPLEMENTATION
     
     private func fetchData<T: Decodable>(
         endpoint: String,
         params: [String: String] = [:],
         type: T.Type
     ) async throws -> T {
         
         // FIX: await connectionService
         guard let url = await connectionService.buildURL(endpoint: endpoint, params: params) else {
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
 }

 // Support types (Moved to SearchModel.swift or kept here if specific)
 enum SearchCategory: Sendable {
     case all, artists, albums, songs
 }

 struct SearchFilters: Sendable {
     let yearRange: ClosedRange<Int>?
     let genre: String?
     let minAlbumCount: Int?
     let durationRange: ClosedRange<Int>?
     
     static let empty = SearchFilters(yearRange: nil, genre: nil, minAlbumCount: nil, durationRange: nil)
 }
 
*/
