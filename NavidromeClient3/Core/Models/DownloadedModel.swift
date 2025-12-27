//
//  DownloadedModel.swift
//  NavidromeClient
//
//  Swift 6: Full Concurrency Support
//

struct DownloadedAlbum: Codable, Sendable, Equatable {
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
    
    // Computed property for current folder path
    // Note: FileManager is Sendable as of iOS 13+
    var folderPath: String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath
            .appendingPathComponent("Downloads", isDirectory: true)
            .appendingPathComponent(albumId, isDirectory: true)
            .path
    }
}

struct DownloadedSong: Codable, Sendable, Equatable, Identifiable {
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
