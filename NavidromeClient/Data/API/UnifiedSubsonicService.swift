//
//  UnifiedSubsonicService.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Compliance
//  - Restored Content Operations (getAllAlbums, getArtists, etc.)
//  - SearchService disabled
//

import Foundation
import UIKit

@MainActor
class UnifiedSubsonicService: ObservableObject {
    
    // MARK: - Properties
    
    let baseURL: URL
    let connectionService: ConnectionService
    let authHeader: [String: String]
    
    // Internal Services
    private let discoveryService: DiscoveryService
    private let mediaService: MediaService
    private let contentService: ContentService
    private let favoritesService: FavoritesService
    
    // Search is currently disabled
    // private let searchService: SearchService
    
    // MARK: - Initialization
    
    init(baseURL: URL, username: String, password: String) {
        self.baseURL = baseURL
        let connection = ConnectionService(baseURL: baseURL, username: username, password: password)
        self.connectionService = connection
        self.authHeader = connection.getAuthHeader()
        
        self.discoveryService = DiscoveryService(connectionService: connection)
        self.mediaService = MediaService(connectionService: connection)
        self.contentService = ContentService(connectionService: connection)
        self.favoritesService = FavoritesService(connectionService: connection)
        
        // self.searchService = SearchService(connectionService: connection)
        
        AppLogger.general.info("UnifiedSubsonicService: Facade initialized")
    }
    
    // MARK: - Connection
    
    func ping() async -> Bool {
        return await connectionService.ping()
    }
    
    // MARK: - Discovery (Explore)
    
    func getRecentAlbums() async throws -> [Album] {
        return try await discoveryService.getRecentAlbums()
    }
    
    func getRandomAlbums() async throws -> [Album] {
        return try await discoveryService.getRandomAlbums()
    }
    
    func getFrequentAlbums() async throws -> [Album] {
        return try await discoveryService.getFrequentAlbums()
    }
    
    func getNewestAlbums(size: Int = 20) async throws -> [Album] {
        return try await discoveryService.getNewestAlbums(size: size)
    }
    
    // MARK: - Content (Library Operations)
    // Restored methods for MusicLibraryManager
    
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
    
    func getArtists() async throws -> [Artist] {
        return try await contentService.getArtists()
    }
    
    func getGenres() async throws -> [Genre] {
        return try await contentService.getGenres()
    }
    
    func getAlbumsByArtist(artistId: String) async throws -> [Album] {
        return try await contentService.getAlbumsByArtist(artistId: artistId)
    }
    
    func getAlbumsByGenre(genre: String) async throws -> [Album] {
        return try await contentService.getAlbumsByGenre(genre: genre)
    }
    
    func getAlbumDetails(id: String) async throws -> [Song] {
        return try await contentService.getSongs(for: id)
    }
    
    // Alias for getAlbumsByArtist if needed by other components
    func getArtistAlbums(id: String) async throws -> [Album] {
        return try await contentService.getAlbumsByArtist(artistId: id)
    }
    
    // MARK: - Media
    
    func getCoverArt(for id: String, size: Int) async -> UIImage? {
        return await mediaService.getCoverArt(for: id, size: size)
    }
    
    func streamURL(for id: String) -> URL? {
        return mediaService.streamURL(for: id)
    }
    
    // MARK: - Favorites
    
    func star(id: String) async throws {
        try await favoritesService.starSong(id)
    }
    
    func unstar(id: String) async throws {
        try await favoritesService.unstarSong(id)
    }
    
    func starSong(_ id: String) async throws {
        try await favoritesService.starSong(id)
    }
    
    func unstarSong(_ id: String) async throws {
        try await favoritesService.unstarSong(id)
    }
    
    func unstarSongs(_ ids: [String]) async throws {
        try await favoritesService.unstarSongs(ids)
    }
    
    func getStarredSongs() async throws -> [Song] {
        return try await favoritesService.getStarredSongs()
    }
    
    /*
    // MARK: - Search (Disabled)
    func search(_ query: String) async throws -> SearchResult3 {
        return try await searchService.search(query)
    }
    */
}
