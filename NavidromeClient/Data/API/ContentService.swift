//
//  ContentService.swift
//  NavidromeClient
//
//  REFACTORED: Step 2 — NetworkActor
//  Removed @MainActor. Pure data service, no UI state.
//

import Foundation

final class ContentService: Sendable {

    private let network: NetworkActor

    init(network: NetworkActor) {
        self.network = network
    }

    // MARK: - Albums

    // MARK: - Albums

    func getAllAlbums(
        sortBy: AlbumSortType = .alphabetical,
        size: Int = 500,
        offset: Int = 0
    ) async throws -> [Album] {
        let params = [
            "type": sortBy.rawValue,
            "size": "\(size)",
            "offset": "\(offset)"
        ]
        let decoded: SubsonicResponse<AlbumListContainer> = try await network.fetchData(
            endpoint: "getAlbumList2",
            params: params,
            using: network.contentURLSession // removed await
        )
        return decoded.subsonicResponse.albumList2?.album ?? []
    }

    func getAlbumsByArtist(artistId: String) async throws -> [Album] {
        guard !artistId.isEmpty else { return [] }
        let decoded: SubsonicResponse<ArtistDetailContainer> = try await network.fetchData(
            endpoint: "getArtist",
            params: ["id": artistId]
        )
        return decoded.subsonicResponse.artist.album ?? []
    }

    func getAlbumsByGenre(size: Int = 500, genre: String) async throws -> [Album] {
        guard !genre.isEmpty else { return [] }
        let params = ["size": "\(size)", "type": "byGenre", "genre": genre]

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

    func getArtists() async throws -> [Artist] {
        let decoded: SubsonicResponse<ArtistsContainer> = try await network.fetchData(
            endpoint: "getArtists",
            using: network.contentURLSession // removed await
        )
        return decoded.subsonicResponse.artists?.index?.flatMap { $0.artist ?? [] } ?? []
    }

    func getSongs(for albumId: String) async throws -> [Song] {
        guard !albumId.isEmpty else { return [] }
        let decoded: SubsonicResponse<AlbumWithSongsContainer> = try await network.fetchData(
            endpoint: "getAlbum",
            params: ["id": albumId],
            using: network.contentURLSession // removed await
        )
        return decoded.subsonicResponse.album.song ?? []
    }

    func getGenres() async throws -> [Genre] {
        let decoded: SubsonicResponse<GenresContainer> = try await network.fetchData(
            endpoint: "getGenres"
        )
        return decoded.subsonicResponse.genres?.genre ?? []
    }
}

extension ContentService {
    enum AlbumSortType: String, CaseIterable {
        case alphabetical        = "alphabeticalByName"
        case alphabeticalByArtist = "alphabeticalByArtist"
        case newest  = "newest"
        case recent  = "recent"
        case frequent = "frequent"
        case random  = "random"
        case byYear  = "byYear"
        case byGenre = "byGenre"

        var displayName: String {
            switch self {
            case .alphabetical:         return "A-Z (Name)"
            case .alphabeticalByArtist: return "A-Z (Artist)"
            case .newest:               return "Newest"
            case .recent:               return "Recently Played"
            case .frequent:             return "Most Played"
            case .random:               return "Random"
            case .byYear:               return "By Year"
            case .byGenre:              return "By Genre"
            }
        }

        var icon: String {
            switch self {
            case .alphabetical, .alphabeticalByArtist: return "textformat.abc"
            case .newest:   return "sparkles"
            case .recent:   return "clock"
            case .frequent: return "chart.bar"
            case .random:   return "shuffle"
            case .byYear:   return "calendar"
            case .byGenre:  return "music.note.list"
            }
        }
    }
}
