//
//  DownloadedModel.swift
//  NavidromeClient
//
//  FIXED Bug 08: toSong() now returns Song? to propagate the optional from
//  Song.createFromDownload. Callers use compactMap to drop nil entries.
//

import Foundation

struct DownloadedAlbum: Codable, Equatable, Sendable {
    let albumId: String
    let albumName: String
    let artistName: String
    let year: Int?
    let genre: String?
    let songs: [DownloadedSong]
    let downloadDate: Date
    
    var songIds: [String] {
        songs.map { $0.id }
    }
    
    static func folderPath(for albumId: String) -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath
            .appendingPathComponent("Downloads", isDirectory: true)
            .appendingPathComponent(albumId, isDirectory: true)
            .path
    }
    
    var folderPath: String {
        Self.folderPath(for: albumId)
    }
}

struct DownloadedSong: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let artist: String?
    let album: String?
    let albumId: String?
    let track: Int?
    let duration: Int?
    let year: Int?
    let genre: String?
    let contentType: String?
    let fileName: String
    let fileSize: Int64
    let downloadDate: Date
    
    /// Converts this downloaded song record into a playable `Song` model.
    ///
    /// Returns `nil` if the conversion fails (malformed stored data). The
    /// caller in `DownloadManager.getSongsForPlayback` uses `compactMap` so
    /// a single corrupt entry does not take down the rest of the album.
    func toSong() -> Song? {
        Song.createFromDownload(
            id: id,
            title: title,
            duration: duration,
            coverArt: albumId,
            artist: artist,
            album: album,
            albumId: albumId,
            track: track,
            year: year,
            genre: genre,
            contentType: contentType
        )
    }
}
