//
//  DownloadedModel.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Song Initializer Order
//

import Foundation

struct DownloadedAlbum: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let artist: String
    let year: Int?
    let genre: String?
    let coverArtId: String?
    var songs: [DownloadedSong]
    let downloadedAt: Date
    
    var songCount: Int { songs.count }
    var totalDuration: TimeInterval { songs.reduce(0) { $0 + $1.duration } }
}

struct DownloadedSong: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let artist: String?
    let albumId: String
    let trackNumber: Int
    let duration: TimeInterval
    let fileSize: Int64
    let localFileName: String
    
    // FIX: Updated argument order to match Song.init
    func toSong() -> Song {
        Song(
            id: id,
            title: title,
            duration: Int(duration),    // 3rd argument
            coverArt: nil,              // 4th
            artist: artist,             // 5th
            album: nil,                 // 6th
            albumId: albumId,           // 7th
            track: trackNumber,         // 8th
            year: nil,
            genre: nil,
            artistId: nil,
            isVideo: false,
            contentType: "audio/mpeg",
            suffix: "mp3",
            path: nil
        )
    }
}
