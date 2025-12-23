//
//  ArtistsContainer.swift
//  NavidromeClient
//
//  Created by Boris Eder on 15.09.25.
//
import Foundation

// MARK: - Artists
struct ArtistsContainer: Codable {
    let artists: ArtistsIndex?
}

struct ArtistsIndex: Codable {
    let index: [ArtistIndex]?
}

struct ArtistIndex: Codable {
    let name: String
    let artist: [Artist]?
}

struct Artist: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let coverArt: String?
    let albumCount: Int?          // KORRIGIERT: Optional gemacht
    let artistImageUrl: String?   // HINZUGEFÜGT: Fehlendes Feld
    
    enum CodingKeys: String, CodingKey {
        case id, name, coverArt, albumCount, artistImageUrl
    }
}

// MARK: - Artist Detail (Albums by Artist)
struct ArtistDetailContainer: Codable {
    let artist: ArtistDetail
}

struct ArtistDetail: Codable {
    let id: String
    let name: String
    let album: [Album]?
}
