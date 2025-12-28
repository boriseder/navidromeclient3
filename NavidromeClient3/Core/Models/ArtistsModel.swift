//
//  ArtistsModel.swift
//  NavidromeClient3
//
//  Swift 6: Full Concurrency Support
//  Fixed: Removed duplicate Album definitions
//

import Foundation

// MARK: - Artists
struct ArtistsContainer: Codable, Sendable {
    let artists: ArtistsIndex?
}

struct ArtistsIndex: Codable, Sendable {
    let index: [ArtistIndex]?
}

struct ArtistIndex: Codable, Sendable {
    let name: String
    let artist: [Artist]?
}

struct Artist: Codable, Identifiable, Hashable, Sendable {
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
struct ArtistDetailContainer: Codable, Sendable {
    let artist: ArtistDetail
}

struct ArtistDetail: Codable, Sendable {
    let id: String
    let name: String
    let album: [Album]?
}
