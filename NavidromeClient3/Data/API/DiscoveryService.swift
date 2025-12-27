//
//  DiscoveryService.swift
//  NavidromeClient
//
//  Swift 6: Actor Migration
//

import Foundation

actor DiscoveryService {
    private let connectionService: ConnectionService
    
    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
    }
    
    func getRecentAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: "recent", size: size)
    }
    
    func getNewestAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: "newest", size: size)
    }
    
    func getFrequentAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: "frequent", size: size)
    }
    
    func getRandomAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: "random", size: size)
    }
    
    func getDiscoveryMix(size: Int = 20) async throws -> DiscoveryMix {
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
    
    func getPopularGenres(limit: Int = 10) async throws -> [GenreWithAlbumCount] {
        let decoded: SubsonicResponse<GenresContainer> = try await fetchData(endpoint: "getGenres")
        
        let genres = decoded.subsonicResponse.genres?.genre ?? []
        return genres
            .map { GenreWithAlbumCount(genre: $0.value, albumCount: $0.albumCount) }
            .sorted { $0.albumCount > $1.albumCount }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Private
    
    private func getAlbumList(type: String, size: Int) async throws -> [Album] {
        let params = ["type": type, "size": "\(size)"]
        let decoded: SubsonicResponse<AlbumListContainer> = try await fetchData(
            endpoint: "getAlbumList2",
            params: params
        )
        return decoded.subsonicResponse.albumList2.album
    }
    
    private func fetchData<T: Decodable & Sendable>(
        endpoint: String,
        params: [String: String] = [:]
    ) async throws -> T {
        // FIX: await connectionService
        guard let url = await connectionService.buildURL(endpoint: endpoint, params: params) else {
            throw SubsonicError.badURL
        }
        
        // Use connectionService to fetch data
        let (data, response) = try await connectionService.getData(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SubsonicError.unknown
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Supporting Types (Sendable)
struct DiscoveryMix: Sendable {
    let recent: [Album]
    let newest: [Album]
    let frequent: [Album]
    let random: [Album]
}

struct GenreWithAlbumCount: Sendable {
    let genre: String
    let albumCount: Int
}
