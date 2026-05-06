//
//  UnifiedSubsonicService.swift
//  NavidromeClient
//
//  REFACTORED: Step 2 — NetworkActor
//  Facade is now a Sendable final class, off the MainActor.
//  Connection testing delegates directly to NetworkActor.
//

import Foundation
import UIKit

final class UnifiedSubsonicService: Sendable {

    let baseURL: URL
    let authHeader: [String: String]

    private let network: NetworkActor
    private let discoveryService: DiscoveryService
    private let mediaService: MediaService
    private let contentService: ContentService
    private let favoritesService: FavoritesService

    init(baseURL: URL, username: String, password: String) {
        self.baseURL = baseURL

        let network = NetworkActor(baseURL: baseURL, username: username, password: password)
        self.network = network
        self.authHeader = network.authHeader()

        self.discoveryService  = DiscoveryService(network: network)
        self.mediaService      = MediaService(network: network)
        self.contentService    = ContentService(network: network)
        self.favoritesService  = FavoritesService(network: network)

        AppLogger.general.info("UnifiedSubsonicService: Initialized with NetworkActor")
    }

    // MARK: - Connection

    func ping() async -> Bool {
        do {
            _ = try await network.ping()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Discovery

    func getRecentAlbums(size: Int = 20)   async throws -> [Album] { try await discoveryService.getRecentAlbums(size: size) }
    func getRandomAlbums(size: Int = 20)   async throws -> [Album] { try await discoveryService.getRandomAlbums(size: size) }
    func getFrequentAlbums(size: Int = 20) async throws -> [Album] { try await discoveryService.getFrequentAlbums(size: size) }
    func getNewestAlbums(size: Int = 20)   async throws -> [Album] { try await discoveryService.getNewestAlbums(size: size) }

    // MARK: - Content

    func getAllAlbums(sortBy: ContentService.AlbumSortType = .alphabetical, size: Int = 500, offset: Int = 0) async throws -> [Album] {
        try await contentService.getAllAlbums(sortBy: sortBy, size: size, offset: offset)
    }
    func getArtists() async throws -> [Artist]              { try await contentService.getArtists() }
    func getGenres()  async throws -> [Genre]               { try await contentService.getGenres() }
    func getAlbumsByArtist(artistId: String) async throws -> [Album] { try await contentService.getAlbumsByArtist(artistId: artistId) }
    func getAlbumsByGenre(genre: String)     async throws -> [Album] { try await contentService.getAlbumsByGenre(genre: genre) }
    func getAlbumDetails(id: String)         async throws -> [Song]  { try await contentService.getSongs(for: id) }
    func getArtistAlbums(id: String)         async throws -> [Album] { try await contentService.getAlbumsByArtist(artistId: id) }

    // MARK: - Media

    func getCoverArt(for id: String, size: Int) async -> UIImage? { await mediaService.getCoverArt(for: id, size: size) }
    func streamURL(for id: String) -> URL? { mediaService.streamURL(for: id) }

    // MARK: - Favorites

    func star(id: String)   async throws { try await favoritesService.starSong(id) }
    func unstar(id: String) async throws { try await favoritesService.unstarSong(id) }
    func starSong(_ id: String)    async throws { try await favoritesService.starSong(id) }
    func unstarSong(_ id: String)  async throws { try await favoritesService.unstarSong(id) }
    func unstarSongs(_ ids: [String]) async throws { try await favoritesService.unstarSongs(ids) }
    func getStarredSongs() async throws -> [Song] { try await favoritesService.getStarredSongs() }
}
