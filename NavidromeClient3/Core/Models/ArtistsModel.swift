//
//  AlbumModel.swift
//  NavidromeClient3
//
//  Swift 6: Full Concurrency Support
//

import Foundation

// MARK: - Albums
struct AlbumListContainer: Codable, Sendable {
    let albumList2: AlbumList
}

struct AlbumList: Codable, Sendable {
    let album: [Album]
}

struct Album: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let artist: String
    let year: Int?
    let genre: String?
    let coverArt: String?
    let coverArtId: String?
    let duration: Int?
    let songCount: Int?
    let artistId: String?
    let displayArtist: String?
    
    enum CodingKeys: String, CodingKey {
        case id, artist, year, genre, duration, songCount, artistId, displayArtist
        case name = "name"
        case title = "title"
        case coverArt = "coverArt"
        case coverArtId = "albumArt"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        artist = try container.decode(String.self, forKey: .artist)
        
        if let title = try container.decodeIfPresent(String.self, forKey: .title) {
            name = title
        } else {
            name = try container.decode(String.self, forKey: .name)
        }
        
        if let coverArt = try container.decodeIfPresent(String.self, forKey: .coverArt) {
            self.coverArt = coverArt
            self.coverArtId = nil
        } else {
            self.coverArt = try container.decodeIfPresent(String.self, forKey: .coverArtId)
            self.coverArtId = self.coverArt
        }
        
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        genre = try container.decodeIfPresent(String.self, forKey: .genre)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        songCount = try container.decodeIfPresent(Int.self, forKey: .songCount)
        artistId = try container.decodeIfPresent(String.self, forKey: .artistId)
        displayArtist = try container.decodeIfPresent(String.self, forKey: .displayArtist)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(artist, forKey: .artist)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encodeIfPresent(genre, forKey: .genre)
        try container.encodeIfPresent(coverArt, forKey: .coverArt)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(songCount, forKey: .songCount)
        try container.encodeIfPresent(artistId, forKey: .artistId)
        try container.encodeIfPresent(displayArtist, forKey: .displayArtist)
    }
}

// MARK: - Album with Songs
struct AlbumWithSongsContainer: Codable, Sendable {
    let album: AlbumWithSongs
}

struct AlbumWithSongs: Codable, Sendable {
    let id: String
    let name: String
    let song: [Song]?
}

//
//  ArtistsModel.swift
//  NavidromeClient3
//
//  Swift 6: Full Concurrency Support
//

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
