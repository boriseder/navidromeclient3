//
//  DownloadedAlbum.swift
//  NavidromeClient
//
//  Created by Boris Eder on 15.09.25.
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
    
    // SWIFT 6 FIX: Make folderPath a static method to avoid @MainActor issues
    static func folderPath(for albumId: String) -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath
            .appendingPathComponent("Downloads", isDirectory: true)
            .appendingPathComponent(albumId, isDirectory: true)
            .path
    }
    
    // Convenience computed property for this instance
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
    
    func toSong() -> Song {
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
