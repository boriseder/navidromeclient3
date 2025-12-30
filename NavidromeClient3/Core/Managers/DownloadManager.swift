//
//  DownloadManager.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Compiler Warnings & Restored Metadata Saving
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class DownloadManager: NSObject {
    static let shared = DownloadManager()
    
    // MARK: - State
    var downloadedAlbums: [DownloadedAlbum] = []
    var activeDownloads: [String: Double] = [:] // SongID -> Progress
    var downloadErrors: [String: String] = [:]
    
    var isDownloading: Bool { !activeDownloads.isEmpty }
    
    // MARK: - Dependencies
    private weak var service: UnifiedSubsonicService?
    private weak var coverArtManager: CoverArtManager?
    
    // MARK: - Infrastructure
    private var session: URLSession!
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    
    // FIX: Store metadata in memory so we can save it when the background task finishes
    private var pendingMetadata: [String: (song: Song, album: Album?)] = [:]
    
    private let fileManager = FileManager.default
    private let downloadsDirectory: URL
    private let metadataFile: URL
    
    // MARK: - Initialization
    
    private override init() {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("Downloads", isDirectory: true)
        self.downloadsDirectory = dir
        self.metadataFile = dir.appendingPathComponent("library_manifest.json")
        
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        
        super.init()
        
        let config = URLSessionConfiguration.background(withIdentifier: "com.navidrome.client.downloads")
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        loadMetadata()
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    func configure(coverArtManager: CoverArtManager) {
        self.coverArtManager = coverArtManager
    }
    
    // MARK: - Public API
    
    func isAlbumDownloaded(_ albumId: String) -> Bool {
        downloadedAlbums.contains { $0.id == albumId }
    }
    
    func isSongDownloaded(_ songId: String) -> Bool {
        for album in downloadedAlbums {
            if album.songs.contains(where: { $0.id == songId }) { return true }
        }
        return false
    }
    
    func getLocalFileURL(for songId: String) -> URL? {
        // Find filename from metadata
        for album in downloadedAlbums {
            if let song = album.songs.first(where: { $0.id == songId }) {
                let fileURL = downloadsDirectory.appendingPathComponent(song.localFileName)
                return fileManager.fileExists(atPath: fileURL.path) ? fileURL : nil
            }
        }
        return nil
    }
    
    // MARK: - Compatibility Extension
    // Alias for compatibility with older view code
    func download(song: Song) async {
        await downloadSong(song)
    }
    
    func isDownloaded(_ songId: String) -> Bool {
        isSongDownloaded(songId)
    }
    
    // MARK: - Actions
    
    func downloadAlbum(album: Album, songs: [Song]) async {
        // FIX: Removed unused 'dlSongs' variable
        
        // Cache Cover Art
        if let coverId = album.coverArt {
            _ = await coverArtManager?.loadAlbumImage(for: coverId, context: .custom(displaySize: 1000, scale: 2))
        }
        
        // Start Song Downloads
        for song in songs {
            await downloadSong(song, albumInfo: album)
        }
    }
    
    func downloadSong(_ song: Song, albumInfo: Album? = nil) async {
        guard !isSongDownloaded(song.id), activeDownloads[song.id] == nil else { return }
        guard let service = service else { return }
        
        guard let url = await service.downloadURL(for: song.id) else { return }
        
        // FIX: Removed unused 'fileName' variable
        
        // FIX: Store metadata for later saving
        pendingMetadata[song.id] = (song, albumInfo)
        
        // Register Task
        let task = session.downloadTask(with: url)
        task.taskDescription = song.id
        task.resume()
        
        activeDownloads[song.id] = 0.0
        activeTasks[song.id] = task
    }
    
    func deleteDownload(albumId: String) {
        guard let index = downloadedAlbums.firstIndex(where: { $0.id == albumId }) else { return }
        let album = downloadedAlbums[index]
        
        // Delete files
        for song in album.songs {
            let url = downloadsDirectory.appendingPathComponent(song.localFileName)
            try? fileManager.removeItem(at: url)
        }
        
        // Update State
        downloadedAlbums.remove(at: index)
        saveMetadata()
    }
    
    // MARK: - Metadata Persistence
    
    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metadataFile),
              let loaded = try? JSONDecoder().decode([DownloadedAlbum].self, from: data) else {
            return
        }
        self.downloadedAlbums = loaded
    }
    
    private func saveMetadata() {
        if let data = try? JSONEncoder().encode(downloadedAlbums) {
            try? data.write(to: metadataFile)
        }
    }
    
    // MARK: - Internal Helper
    
    fileprivate func registerDownloadedSong(id: String, location: URL, fileSize: Int64) {
        // 1. Move file to permanent location
        let fileName = "\(id).mp3"
        let destURL = downloadsDirectory.appendingPathComponent(fileName)
        
        do {
            try? fileManager.removeItem(at: destURL)
            try fileManager.moveItem(at: location, to: destURL)
        } catch {
            AppLogger.general.error("Failed to move downloaded file for \(id): \(error)")
            return
        }
        
        // 2. Retrieve Metadata & Update Manifest
        guard let (song, albumInfo) = pendingMetadata[id] else {
            AppLogger.general.error("Missing metadata for downloaded song \(id)")
            return
        }
        
        // 3. Create DownloadedSong Entry
        let dlSong = DownloadedSong(
            id: song.id,
            title: song.title,
            artist: song.artist,
            albumId: albumInfo?.id ?? song.albumId ?? "unknown_album",
            trackNumber: song.track ?? 0,
            duration: TimeInterval(song.duration ?? 0),
            fileSize: fileSize,
            localFileName: fileName
        )
        
        // 4. Update or Create Album Entry
        let albumId = albumInfo?.id ?? song.albumId ?? "unknown_album"
        
        if let index = downloadedAlbums.firstIndex(where: { $0.id == albumId }) {
            // Append to existing
            if !downloadedAlbums[index].songs.contains(where: { $0.id == song.id }) {
                downloadedAlbums[index].songs.append(dlSong)
            }
        } else {
            // Create new album entry
            let newAlbum = DownloadedAlbum(
                id: albumId,
                title: albumInfo?.name ?? song.album ?? "Unknown Album",
                artist: albumInfo?.artist ?? song.artist ?? "Unknown Artist",
                year: albumInfo?.year ?? song.year,
                genre: albumInfo?.genre ?? song.genre,
                coverArtId: albumInfo?.coverArt ?? song.coverArt,
                songs: [dlSong],
                downloadedAt: Date()
            )
            downloadedAlbums.append(newAlbum)
        }
        
        // 5. Save & Cleanup
        saveMetadata()
        pendingMetadata.removeValue(forKey: id)
        AppLogger.general.info("Successfully registered download: \(song.title)")
    }
}

// MARK: - URLSession Delegate
extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription else { return }
        
        // Get file size approximation
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: location.path)[.size] as? Int64) ?? 0
        
        Task { @MainActor in
            self.registerDownloadedSong(id: id, location: location, fileSize: fileSize)
            self.activeDownloads.removeValue(forKey: id)
            self.activeTasks.removeValue(forKey: id)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.activeDownloads[id] = progress
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = task.taskDescription else { return }
        if let error = error {
            Task { @MainActor in
                self.downloadErrors[id] = error.localizedDescription
                self.activeDownloads.removeValue(forKey: id)
                self.activeTasks.removeValue(forKey: id)
                self.pendingMetadata.removeValue(forKey: id)
            }
        }
    }
}
