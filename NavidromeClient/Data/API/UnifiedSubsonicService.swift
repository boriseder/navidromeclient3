//
//  UnifiedSubsonicService.swift - COMPLETE FACADE PATTERN
//  NavidromeClient
//
//  COMPLETE: All operations delegated to private specialists
//  ADDED: FavoritesService integration
//  CLEAN: No direct specialist access from outside
//

import Foundation
import UIKit

@MainActor
class UnifiedSubsonicService: ObservableObject {
    
    // MARK: - Private Specialists
    
    private let connectionService: ConnectionService
    private let contentService: ContentService
    private let mediaService: MediaService
    private let discoveryService: DiscoveryService
    private let favoritesService: FavoritesService

    // -------- SearchService disabled -------- //
    /*
    private let searchService: SearchService
    */
    // -------- SearchService disabled -------- //
    
    // MARK: - Initialization
    
    init(baseURL: URL, username: String, password: String) {
        self.connectionService = ConnectionService(
            baseURL: baseURL,
            username: username,
            password: password
        )
        
        self.contentService = ContentService(connectionService: connectionService)
        self.mediaService = MediaService(connectionService: connectionService)
        self.discoveryService = DiscoveryService(connectionService: connectionService)
        self.favoritesService = FavoritesService(connectionService: connectionService)
        //  ---
        /*
        self.searchService = SearchService(connectionService: connectionService)
        */
        // ---
        
        AppLogger.general.info("UnifiedSubsonicService: Facade initialized with all specialists including favorites")
    }
    
    // MARK: - Connection Operations
    
    func testConnection() async -> ConnectionTestResult {
        return await connectionService.testConnection()
    }
    
    func ping() async -> Bool {
        return await connectionService.ping()
    }
    
    func performHealthCheck() async -> ConnectionHealth {
        return await connectionService.performHealthCheck()
    }
    
    func buildURL(endpoint: String, params: [String: String] = [:]) -> URL? {
        return connectionService.buildURL(endpoint: endpoint, params: params)
    }
    
    // MARK: - Content Operations: Albums
    
    func getAllAlbums(
        sortBy: ContentService.AlbumSortType = .alphabetical,
        size: Int = 500,
        offset: Int = 0
    ) async throws -> [Album] {
        return try await contentService.getAllAlbums(
            sortBy: sortBy,
            size: size,
            offset: offset
        )
    }
    
    func getAlbumsByArtist(artistId: String) async throws -> [Album] {
        guard !artistId.isEmpty else { return [] }
        return try await contentService.getAlbumsByArtist(artistId: artistId)
    }
    
    func getAlbumsByGenre(genre: String) async throws -> [Album] {
        guard !genre.isEmpty else { return [] }
        return try await contentService.getAlbumsByGenre(genre: genre)
    }
    
    // MARK: - Content Operations: Artists
    
    func getArtists() async throws -> [Artist] {
        return try await contentService.getArtists()
    }
    
    // MARK: - Content Operations: Songs
    
    func getSongs(for albumId: String) async throws -> [Song] {
        guard !albumId.isEmpty else { return [] }
        return try await contentService.getSongs(for: albumId)
    }
    
    // MARK: - Content Operations: Genres
    
    func getGenres() async throws -> [Genre] {
        return try await contentService.getGenres()
    }
    
    // MARK: - Media Operations: Cover Art
    
    func getCoverArt(for coverId: String, size: Int = 300) async -> UIImage? {
        guard !coverId.isEmpty else { return nil }
        return await mediaService.getCoverArt(for: coverId, size: size)
    }
    
    func preloadCoverArt(for albums: [Album], size: Int = 200) async {
        guard !albums.isEmpty else { return }
        await mediaService.preloadCoverArt(for: albums, size: size)
    }
    
    func getCoverArtBatch(
        items: [(id: String, size: Int)],
        maxConcurrent: Int = 3
    ) async -> [String: UIImage] {
        guard !items.isEmpty else { return [:] }
        return await mediaService.getCoverArtBatch(
            items: items,
            maxConcurrent: maxConcurrent
        )
    }
    
    func clearCoverArtCache() {
        mediaService.clearCoverArtCache()
    }
    
    func getCoverArtCacheStats() -> MediaCacheStats {
        return mediaService.getCacheStats()
    }
    
    // MARK: - Media Operations: Streaming
    
    func streamURL(for songId: String) -> URL? {
        guard !songId.isEmpty else { return nil }
        return mediaService.streamURL(for: songId)
    }
    
    func downloadURL(for songId: String, maxBitRate: Int? = nil) -> URL? {
        guard !songId.isEmpty else { return nil }
        return mediaService.downloadURL(for: songId, maxBitRate: maxBitRate)
    }
    
    /*
    func getOptimalStreamURL(
        for songId: String,
        preferredBitRate: Int? = nil,
        connectionQuality: ConnectionService.ConnectionQuality
    ) -> URL? {
        guard !songId.isEmpty else { return nil }
        return mediaService.getOptimalStreamURL(
            for: songId,
            preferredBitRate: preferredBitRate,
            connectionQuality: connectionQuality
        )
    }
    */
    
    func getMediaInfo(for songId: String) async throws -> MediaInfo? {
        guard !songId.isEmpty else { return nil }
        return try await mediaService.getMediaInfo(for: songId)
    }
    
    // MARK: - Discovery Operations: Home Screen
    
    func getRecentAlbums(size: Int = 20) async throws -> [Album] {
        return try await discoveryService.getRecentAlbums(size: size)
    }
    
    func getNewestAlbums(size: Int = 20) async throws -> [Album] {
        return try await discoveryService.getNewestAlbums(size: size)
    }
    
    func getFrequentAlbums(size: Int = 20) async throws -> [Album] {
        return try await discoveryService.getFrequentAlbums(size: size)
    }
    
    func getRandomAlbums(size: Int = 20) async throws -> [Album] {
        return try await discoveryService.getRandomAlbums(size: size)
    }
    
    func refreshRandomAlbums(size: Int = 20) async throws -> [Album] {
        return try await discoveryService.getRandomAlbums(size: size)
    }
    
    // MARK: - Discovery Operations: Discovery Mix
    
    func getDiscoveryMix(size: Int = 20) async throws -> DiscoveryMix {
        return try await discoveryService.getDiscoveryMix(size: size)
    }
    
    // MARK: - Discovery Operations: Recommendations
    
    func getRecommendationsFor(artist: Artist, limit: Int = 10) async throws -> [Album] {
        return try await discoveryService.getRecommendationsFor(
            artist: artist,
            limit: limit
        )
    }
    
    func getRecommendationsFor(album: Album, limit: Int = 10) async throws -> [Album] {
        return try await discoveryService.getRecommendationsFor(
            album: album,
            limit: limit
        )
    }
    
    // MARK: - Discovery Operations: Genre-Based
    
    func getAlbumsByGenreForDiscovery(genre: String, limit: Int = 20) async throws -> [Album] {
        guard !genre.isEmpty else { return [] }
        return try await discoveryService.getAlbumsByGenre(genre: genre, limit: limit)
    }
    
    func getPopularGenres(limit: Int = 10) async throws -> [GenreWithAlbumCount] {
        return try await discoveryService.getPopularGenres(limit: limit)
    }
    
    // MARK: - Discovery Operations: Time-Based
    
    func getAlbumsFromYear(year: Int, limit: Int = 20) async throws -> [Album] {
        return try await discoveryService.getAlbumsFromYear(year: year, limit: limit)
    }
    
    func getAlbumsFromDecade(decade: Int, limit: Int = 20) async throws -> [Album] {
        return try await discoveryService.getAlbumsFromDecade(decade: decade, limit: limit)
    }
    
    // MARK: - Search Operations: Basic Search
    // disbaled
    /* ---

    func search(query: String, maxResults: Int = 50) async throws -> SearchResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return SearchResult(artists: [], albums: [], songs: [])
        }
        
        return try await searchService.search(query: trimmedQuery, maxResults: maxResults)
    }
    
    // MARK: - Search Operations: Advanced Search
    func searchByCategory(
        query: String,
        category: SearchCategory,
        maxResults: Int = 50
    ) async throws -> SearchResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return SearchResult(artists: [], albums: [], songs: [])
        }
        
        return try await searchService.searchByCategory(
            query: trimmedQuery,
            category: category,
            maxResults: maxResults
        )
    }
    
    func searchWithFilters(
        query: String,
        filters: SearchFilters,
        maxResults: Int = 50
    ) async throws -> SearchResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return SearchResult(artists: [], albums: [], songs: [])
        }
        
        return try await searchService.searchWithFilters(
            query: trimmedQuery,
            filters: filters,
            maxResults: maxResults
        )
    }
    
    // MARK: - Search Operations: Suggestions
    
    func getSearchSuggestions(for partialQuery: String, limit: Int = 5) async -> [String] {
        let trimmedQuery = partialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { return [] }
        
        return await searchService.getSearchSuggestions(for: trimmedQuery, limit: limit)
    }
    
    // MARK: - Search Operations: Ranking
    
    func rankSearchResults(_ results: SearchResult, for query: String) -> SearchResult {
        return searchService.rankSearchResults(results, for: query)
    }
    
    --- */
    
    // MARK: - Favorites Operations
    
    func starSong(_ songId: String) async throws {
        guard !songId.isEmpty else { return }
        try await favoritesService.starSong(songId)
    }
    
    func unstarSong(_ songId: String) async throws {
        guard !songId.isEmpty else { return }
        try await favoritesService.unstarSong(songId)
    }
    
    func getStarredSongs() async throws -> [Song] {
        return try await favoritesService.getStarredSongs()
    }
    
    func unstarSongs(_ songIds: [String]) async throws {
        guard !songIds.isEmpty else { return }
        try await favoritesService.unstarSongs(songIds)
    }
    
    // MARK: - Health & Diagnostics
    
    func clearAllCaches() {
        mediaService.clearCoverArtCache()
        AppLogger.general.info("All service caches cleared")
    }
    
    func getServiceDiagnostics() async -> ServiceDiagnostics {
        let connectionHealth = await connectionService.performHealthCheck()
        let mediaCacheStats = mediaService.getCacheStats()
        
        return ServiceDiagnostics(
            isHealthy: connectionHealth.isConnected,
            connectionHealth: connectionHealth,
            mediaCacheStats: mediaCacheStats,
            timestamp: Date()
        )
    }
    
    struct ServiceDiagnostics {
        let isHealthy: Bool
        let connectionHealth: ConnectionHealth
        let mediaCacheStats: MediaCacheStats
        let timestamp: Date
        
        var summary: String {
            return """
            SERVICE DIAGNOSTICS
            Status: \(isHealthy ? "Healthy" : "Unhealthy")
            Connection: \(connectionHealth.statusDescription)
            Media Cache: \(mediaCacheStats.summary)
            Timestamp: \(timestamp)
            """
        }
    }
}

// MARK: - Internal Service Access (For Managers Only)

extension UnifiedSubsonicService {
     
    private func getConnectionService() -> ConnectionService {
        return connectionService
    }
    
    private func getContentService() -> ContentService {
        return contentService
    }
    
    private func getMediaService() -> MediaService {
        return mediaService
    }
    
    private func getDiscoveryService() -> DiscoveryService {
        return discoveryService
    }
    // ---
    /*
    private func getSearchService() -> SearchService {
        return searchService
    }
    */
    // --- 
    private func getFavoritesService() -> FavoritesService {
        return favoritesService
    }
}

// MARK: - Legacy Type Alias
typealias SubsonicService = UnifiedSubsonicService
