//
//  SongModel.swift
//  NavidromeClient
//
//  FIXED Bug 08: createFromDownload no longer uses fatalError.
//  Returns Song? and logs the error instead of crashing in production.
//

import Foundation

struct Song: Codable, Identifiable, Sendable {
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
        case id, title, duration, coverArt, artist, album, albumId
        case track, year, genre, artistId, isVideo, contentType, suffix, path
    }
    
    init(from decoder: Decoder) throws {
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
    /// Creates a Song from locally downloaded metadata.
    ///
    /// Returns `nil` if JSON serialisation or decoding fails, rather than
    /// crashing with `fatalError`. Callers must handle the optional — see
    /// `DownloadedSong.toSong()` and `DownloadManager.getSongsForPlayback`.
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
    ) -> Song? {
        let songData: [String: Any?] = [
            "id": id,
            "title": title,
            "duration": duration,
            "coverArt": coverArt,
            "artist": artist,
            "album": album,
            "albumId": albumId,
            "track": track,
            "year": year,
            "genre": genre,
            "artistId": nil,
            "isVideo": false,
            "contentType": contentType ?? "audio/mpeg",
            "suffix": "mp3",
            "path": nil
        ]

        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: songData.compactMapValues { $0 }
            )
            return try JSONDecoder().decode(Song.self, from: jsonData)
        } catch {
            // Log and return nil — never crash in production over a missing
            // downloaded song. The caller skips it via compactMap.
            AppLogger.ui.error(
                "❌ createFromDownload failed for '\(title)' (id: \(id)): \(error)"
            )
            return nil
        }
    }
}
