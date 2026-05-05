//
//  DiscoveryService.swift
//  NavidromeClient
//
//  REFACTORED: Step 2 — NetworkActor
//

import Foundation

final class DiscoveryService: Sendable {

    private let network: NetworkActor

    init(network: NetworkActor) {
        self.network = network
    }

    func getRecentAlbums(size: Int = 20)   async throws -> [Album] { try await getAlbumList(type: .recent,   size: size) }
    func getNewestAlbums(size: Int = 20)   async throws -> [Album] { try await getAlbumList(type: .newest,   size: size) }
    func getFrequentAlbums(size: Int = 20) async throws -> [Album] { try await getAlbumList(type: .frequent, size: size) }
    func getRandomAlbums(size: Int = 20)   async throws -> [Album] { try await getAlbumList(type: .random,   size: size) }

    private func getAlbumList(type: AlbumListType, size: Int, offset: Int = 0) async throws -> [Album] {
        let params = ["type": type.rawValue, "size": "\(size)", "offset": "\(offset)"]
        let fallback = SubsonicResponse<AlbumListContainer>(
            subsonicResponse: AlbumListContainer(albumList2: AlbumList(album: []))
        )
        let decoded: SubsonicResponse<AlbumListContainer> = try await network.fetchDataWithFallback(
            endpoint: "getAlbumList2",
            params: params,
            fallback: fallback
        )
        return decoded.subsonicResponse.albumList2?.album ?? []
    }

    enum AlbumListType: String {
        case recent = "recent", newest = "newest", frequent = "frequent"
        case random = "random", byGenre = "byGenre", byYear = "byYear"
    }
}
