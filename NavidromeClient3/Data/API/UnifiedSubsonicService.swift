//
//  UnifiedSubsonicService.swift
//  NavidromeClient
//
//  Swift 6: Facade Actor
//

import Foundation
import UIKit

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
        
        // Log removed or wrapped if AppLogger is MainActor isolated.
        // Assuming we can skip log in init or use print for safety in this strict context.
        print("UnifiedSubsonicService: Initialized")
    }
    
    // MARK: - Delegated API (All Async)
    
    func ping() async -> Bool {
        return await connectionService.ping()
    }
    
    func getAllAlbums(sortBy: AlbumSortType, size: Int, offset: Int) async throws -> [Album] {
        try await contentService.getAllAlbums(sortBy: sortBy, size: size, offset: offset)
    }
    
    func getArtists() async throws -> [Artist] {
        try await contentService.getArtists()
    }
    
    func getGenres() async throws -> [Genre] {
        try await contentService.getGenres()
    }
    
    func getSongs(for albumId: String) async throws -> [Song] {
        try await contentService.getSongs(for: albumId)
    }
    
    func getCoverArt(for id: String, size: Int) async -> UIImage? {
        await mediaService.getCoverArt(for: id, size: size)
    }
    
    func streamURL(for songId: String) async -> URL? {
        await mediaService.streamURL(for: songId)
    }
    
    func downloadURL(for songId: String) async -> URL? {
        await mediaService.downloadURL(for: songId)
    }
    
    func getDiscoveryMix(size: Int) async throws -> DiscoveryMix {
        try await discoveryService.getDiscoveryMix(size: size)
    }
    
    func getRandomAlbums(size: Int) async throws -> [Album] {
        try await discoveryService.getRandomAlbums(size: size)
    }
    
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
