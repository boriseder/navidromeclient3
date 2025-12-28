//
//  DownloadedModel.swift
//  NavidromeClient3
//
//  Swift 6: Fixed imports and conformances
//

import Foundation

// FIX: Added 'nonisolated' to structs to prevent MainActor inference
nonisolated struct DownloadedAlbum: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let artist: String
    let coverArtPath: String?
    let downloadedAt: Date
    var songs: [DownloadedSong]
    
    // Calculated properties that access FileManager are safe as long as they aren't stored
    var localCoverArtURL: URL? {
        guard let path = coverArtPath else { return nil }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(path)
    }
}

nonisolated struct DownloadedSong: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: Int?
    let path: String
    let downloadedAt: Date
    
    var localURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(path)
    }
}
