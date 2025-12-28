//
//  SongModel.swift
//  NavidromeClient3
//
//  Swift 6: Full Concurrency Support
//

import Foundation

// FIX: Mark struct as 'nonisolated' to decouple it from MainActor
nonisolated struct Song: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let duration: Int?
    let coverArt: String?
    let artist: String?
    let album: String?
    let albumId: String?
    let track: Int?
    let year: Int?
    let genre: String?
    let artistId: String?
    let isVideo: Bool?
    let contentType: String?
    let suffix: String?
    let path: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, duration, coverArt, artist, album, albumId, track
        case year, genre, artistId, isVideo, contentType, suffix, path
    }
    
    // MARK: - Initializers
    
    init(
        id: String,
        title: String,
        duration: Int? = nil,
        coverArt: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        albumId: String? = nil,
        track: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        artistId: String? = nil,
        isVideo: Bool? = nil,
        contentType: String? = nil,
        suffix: String? = nil,
        path: String? = nil
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.coverArt = coverArt
        self.artist = artist
        self.album = album
        self.albumId = albumId
        self.track = track
        self.year = year
        self.genre = genre
        self.artistId = artistId
        self.isVideo = isVideo
        self.contentType = contentType
        self.suffix = suffix
        self.path = path
    }
    
    // FIX: Explicitly mark init as nonisolated
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        coverArt = try container.decodeIfPresent(String.self, forKey: .coverArt)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        albumId = try container.decodeIfPresent(String.self, forKey: .albumId)
        track = try container.decodeIfPresent(Int.self, forKey: .track)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        genre = try container.decodeIfPresent(String.self, forKey: .genre)
        artistId = try container.decodeIfPresent(String.self, forKey: .artistId)
        isVideo = try container.decodeIfPresent(Bool.self, forKey: .isVideo)
        contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        suffix = try container.decodeIfPresent(String.self, forKey: .suffix)
        path = try container.decodeIfPresent(String.self, forKey: .path)
    }
}

extension Song {
    static func createFromDownload(
        id: String,
        title: String,
        duration: Int? = nil,
        coverArt: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        albumId: String? = nil,
        track: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        contentType: String? = nil
    ) -> Song {
        Song(
            id: id,
            title: title,
            duration: duration,
            coverArt: coverArt,
            artist: artist,
            album: album,
            albumId: albumId,
            track: track,
            year: year,
            genre: genre,
            artistId: nil,
            isVideo: false,
            contentType: contentType ?? "audio/mpeg",
            suffix: "mp3",
            path: nil
        )
    }
}
