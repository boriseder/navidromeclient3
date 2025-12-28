//
//  UnifiedSubsonicService.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Method Delegation & Return Types
//

import Foundation
import UIKit // For UIImage

actor UnifiedSubsonicService {
    
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
    }
    
    // MARK: - Connection & Status
    
    func ping() async -> Bool {
        return await connectionService.ping()
    }
    
    // MARK: - Content API
    
    func getAllAlbums(sortBy: AlbumSortType, size: Int, offset: Int) async throws -> [Album] {
        // FIX: Delegate to getAllAlbums, not getAlbumList2
        try await contentService.getAllAlbums(sortBy: sortBy, size: size, offset: offset)
    }
    
    func getAlbumsByArtist(artistId: String) async throws -> [Album] {
        // FIX: Delegate to ContentService
        try await contentService.getAlbumsByArtist(artistId: artistId)
    }
    
    func getAlbumsByGenre(genre: String) async throws -> [Album] {
        // FIX: Delegate to ContentService
        try await contentService.getAlbumsByGenre(genre: genre)
    }
    
    func getArtists() async throws -> [Artist] {
        try await contentService.getArtists()
    }
    
    func getGenres() async throws -> [Genre] {
        // FIX: ContentService has getGenres, not DiscoveryService
        try await contentService.getGenres()
    }
    
    func getSongs(for albumId: String) async throws -> [Song] {
        try await contentService.getSongs(for: albumId)
    }
    
    // MARK: - Media API
    
    func getCoverArt(for id: String, size: Int) async -> UIImage? {
        await mediaService.getCoverArt(for: id, size: size)
    }
    
    func streamURL(for songId: String) async -> URL? {
        await mediaService.streamURL(for: songId)
    }
    
    func downloadURL(for songId: String) async -> URL? {
        await mediaService.downloadURL(for: songId)
    }
    
    // MARK: - Discovery API
    
    func getDiscoveryMix(size: Int) async throws -> DiscoveryMix {
        try await discoveryService.getDiscoveryMix(size: size)
    }
    
    func getRandomAlbums(size: Int) async throws -> [Album] {
        try await discoveryService.getRandomAlbums(size: size)
    }
    
    // MARK: - Favorites API
    
    func starSong(_ songId: String) async throws {
        try await favoritesService.starSong(songId)
    }
    
    func unstarSong(_ songId: String) async throws {
        try await favoritesService.unstarSong(songId)
    }
    
    func getStarredSongs() async throws -> [Song] {
        try await favoritesService.getStarredSongs()
    }
}
