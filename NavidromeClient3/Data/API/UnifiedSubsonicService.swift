import Foundation
import UIKit

// FIX: Converted to Actor
actor UnifiedSubsonicService {
    
    // MARK: - Private Specialists
    private let connectionService: ConnectionService
    private let contentService: ContentService
    private let mediaService: MediaService
    private let discoveryService: DiscoveryService
    private let favoritesService: FavoritesService

    init(baseURL: URL, username: String, password: String) {
        let conn = ConnectionService(baseURL: baseURL, username: username, password: password)
        self.connectionService = conn
        
        self.contentService = ContentService(connectionService: conn)
        self.mediaService = MediaService(connectionService: conn)
        self.discoveryService = DiscoveryService(connectionService: conn)
        self.favoritesService = FavoritesService(connectionService: conn)
        
        AppLogger.general.info("UnifiedSubsonicService: Facade initialized")
    }
    
    // MARK: - Delegated Operations
    
    func ping() async -> Bool {
        return await connectionService.ping()
    }
    
    func testConnection() async -> ConnectionTestResult {
        return await connectionService.testConnection()
    }
    
    func getAllAlbums(sortBy: AlbumSortType, size: Int, offset: Int) async throws -> [Album] {
        return try await contentService.getAllAlbums(sortBy: sortBy, size: size, offset: offset)
    }
    
    func getAlbumsByArtist(artistId: String) async throws -> [Album] {
        return try await contentService.getAlbumsByArtist(artistId: artistId)
    }
    
    func getAlbumsByGenre(genre: String) async throws -> [Album] {
        return try await contentService.getAlbumsByGenre(genre: genre)
    }
    
    func getArtists() async throws -> [Artist] {
        return try await contentService.getArtists()
    }
    
    func getSongs(for albumId: String) async throws -> [Song] {
        return try await contentService.getSongs(for: albumId)
    }
    
    func getGenres() async throws -> [Genre] {
        return try await contentService.getGenres()
    }
    
    func getCoverArt(for coverId: String, size: Int = 300) async -> UIImage? {
        return await mediaService.getCoverArt(for: coverId, size: size)
    }
    
    func streamURL(for songId: String) async -> URL? {
        return await mediaService.streamURL(for: songId)
    }
    
    // FIX: This method is required by DownloadManager
    func downloadURL(for songId: String, maxBitRate: Int? = nil) async -> URL? {
        return await mediaService.downloadURL(for: songId, maxBitRate: maxBitRate)
    }
    
    func getRecentAlbums(size: Int) async throws -> [Album] {
        return try await discoveryService.getRecentAlbums(size: size)
    }
    
    func getDiscoveryMix(size: Int) async throws -> DiscoveryMix {
        return try await discoveryService.getDiscoveryMix(size: size)
    }
    
    func getRandomAlbums(size: Int) async throws -> [Album] {
        return try await discoveryService.getRandomAlbums(size: size)
    }
    
    func starSong(_ songId: String) async throws {
        try await favoritesService.starSong(songId)
    }
    
    func unstarSong(_ songId: String) async throws {
        try await favoritesService.unstarSong(songId)
    }
    
    func getStarredSongs() async throws -> [Song] {
        return try await favoritesService.getStarredSongs()
    }
}
