//
//  ArtistsModel.swift
//  NavidromeClient3
//
//  Swift 6: Full Concurrency Support
//

import Foundation

// MARK: - Artists
// FIX: Mark all structs nonisolated
nonisolated struct ArtistsContainer: Codable, Sendable {
    let artists: ArtistsIndex?
}

nonisolated struct ArtistsIndex: Codable, Sendable {
    let index: [ArtistIndex]?
}

nonisolated struct ArtistIndex: Codable, Sendable {
    let name: String
    let artist: [Artist]?
}

nonisolated struct Artist: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let coverArt: String?
    let albumCount: Int?
    let artistImageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, coverArt, albumCount, artistImageUrl
    }
}

// MARK: - Artist Detail
nonisolated struct ArtistDetailContainer: Codable, Sendable {
    let artist: ArtistDetail
}

nonisolated struct ArtistDetail: Codable, Sendable {
    let id: String
    let name: String
    let album: [Album]?
}
