//
//  Song+Extensions.swift - Simple Initializer for Downloaded Songs
//

import Foundation

struct Song: Codable, Identifiable {
    let id: String
    let title: String
    let duration: Int?
    let coverArt: String?
    let artist: String?
    let album: String?
    let albumId: String?     // <- hinzufügen
    let track: Int?
    let year: Int?
    let genre: String?
    let artistId: String?
    let isVideo: Bool?
    let contentType: String?
    let suffix: String?
    let path: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, duration, coverArt, artist, album,albumId, track, year, genre, artistId, isVideo, contentType, suffix, path
    }
    
    // Custom initializer für flexible Dekodierung
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
    
    //  NEW: Simple initializer for downloaded songs (bypasses complex decoder)
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
        
        // Create a dictionary with all required fields
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
        
        // Convert to JSON and back to create proper Song object
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: songData.compactMapValues { $0 })
            let song = try JSONDecoder().decode(Song.self, from: jsonData)
            return song
        } catch {
            AppLogger.ui.error("❌ Failed to create Song from download data: \(error)")
            // Fallback - this should not happen, but just in case
            fatalError("Could not create Song object")
        }
    }
}
