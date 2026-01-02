// MARK: - AlbumModel.swift (Swift 6 Optimized)
import SwiftUI

// MARK: - Albums
struct AlbumListContainer: Codable, Sendable {
    let albumList2: AlbumList?
    let albumList: AlbumList?
    
    // Explicit init to allow omitting arguments
    init(albumList2: AlbumList? = nil, albumList: AlbumList? = nil) {
        self.albumList2 = albumList2
        self.albumList = albumList
    }
}

struct AlbumList: Codable, Sendable {
    let album: [Album]?
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
    
    // Restored properties for OfflineManager/Legacy support
    let isDir: Bool?
    let parent: String?
    let created: Date?
    let song: [Song]?
    let playCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, artist, year, genre, duration, songCount, artistId, displayArtist
        case name = "name"
        case title = "title"
        case coverArt = "coverArt"
        case coverArtId = "albumArt"
        case isDir, parent, created, song, playCount
    }
    
    // Explicit Init for OfflineManager/Previews
    init(
        id: String,
        parent: String? = nil,
        album: String,
        title: String,
        name: String,
        isDir: Bool = true,
        coverArt: String?,
        artist: String,
        artistId: String? = nil,
        created: Date? = nil,
        duration: Int? = 0,
        playCount: Int? = 0,
        songCount: Int? = 0,
        year: Int? = nil,
        genre: String? = nil,
        song: [Song]? = nil
    ) {
        self.id = id
        self.parent = parent
        self.name = !title.isEmpty ? title : name
        self.artist = artist
        self.year = year
        self.genre = genre
        self.coverArt = coverArt
        self.coverArtId = coverArt
        self.duration = duration
        self.songCount = songCount
        self.artistId = artistId
        self.displayArtist = artist
        self.isDir = isDir
        self.created = created
        self.song = song
        self.playCount = playCount
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
        
        // Optional fields
        isDir = try container.decodeIfPresent(Bool.self, forKey: .isDir)
        parent = try container.decodeIfPresent(String.self, forKey: .parent)
        created = try container.decodeIfPresent(Date.self, forKey: .created)
        song = try container.decodeIfPresent([Song].self, forKey: .song)
        playCount = try container.decodeIfPresent(Int.self, forKey: .playCount)
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
        try container.encodeIfPresent(isDir, forKey: .isDir)
        try container.encodeIfPresent(parent, forKey: .parent)
        try container.encodeIfPresent(created, forKey: .created)
        try container.encodeIfPresent(song, forKey: .song)
        try container.encodeIfPresent(playCount, forKey: .playCount)
    }
}

// MARK: - Album with Songs
struct AlbumWithSongsContainer: Codable, Sendable {
    let album: Album
}
