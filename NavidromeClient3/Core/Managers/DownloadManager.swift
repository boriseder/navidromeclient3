//
//  DownloadManager.swift
//  NavidromeClient
//
//  Swift 6: @Observable, Actor Integration & URLSession Delegation
//

import Foundation
import SwiftUI
import Observation
import AVFoundation

@MainActor
@Observable
final class DownloadManager: NSObject {
    static let shared = DownloadManager()
    
    // MARK: - State
    var downloadedSongs: Set<String> = []
    var activeDownloads: [String: Double] = [:]
    
    var isDownloading: Bool { !activeDownloads.isEmpty }
    
    // MARK: - Dependencies
    private weak var service: UnifiedSubsonicService?
    private weak var coverArtManager: CoverArtManager?
    
    // MARK: - Infrastructure
    private var session: URLSession!
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    
    private let fileManager = FileManager.default
    
    // FIX: Correct lazy var syntax (must end with ())
    private lazy var downloadsDirectory: URL = {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("Downloads", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        
        let config = URLSessionConfiguration.background(withIdentifier: "com.navidrome.client.downloads")
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        restoreDownloadedSongs()
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    func configure(coverArtManager: CoverArtManager) {
        self.coverArtManager = coverArtManager
    }
    
    // MARK: - Public API
    
    func isDownloaded(_ songId: String) -> Bool {
        downloadedSongs.contains(songId)
    }
    
    func getLocalFileURL(for songId: String) -> URL? {
        let fileURL = downloadsDirectory.appendingPathComponent("\(songId).mp3")
        return fileManager.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    func download(song: Song) async {
        guard !isDownloaded(song.id), activeDownloads[song.id] == nil else { return }
        guard let service = service else { return }
        
        AppLogger.general.info("Starting download for: \(song.title)")
        
        // FIX: await the actor method
        guard let url = await service.downloadURL(for: song.id) else {
            AppLogger.general.error("Could not generate download URL for \(song.id)")
            return
        }
        
        let task = session.downloadTask(with: url)
        task.taskDescription = song.id
        task.resume()
        
        activeDownloads[song.id] = 0.0
        activeTasks[song.id] = task
        
        // Download Cover Art
        if let coverId = song.coverArt {
            Task {
                // FIX: Use explicit init with scale default from ImageContext.swift
                _ = await coverArtManager?.loadAlbumImage(
                    for: coverId,
                    context: ImageContext(size: 600)
                )
            }
        }
    }
    
    func deleteDownload(for songId: String) {
        if let task = activeTasks[songId] {
            task.cancel()
            activeTasks.removeValue(forKey: songId)
            activeDownloads.removeValue(forKey: songId)
        }
        
        let fileURL = downloadsDirectory.appendingPathComponent("\(songId).mp3")
        try? fileManager.removeItem(at: fileURL)
        
        downloadedSongs.remove(songId)
        saveDownloadedSongs()
        
        AppLogger.general.info("Deleted download: \(songId)")
    }
    
    // MARK: - Persistence
    
    private func restoreDownloadedSongs() {
        do {
            let files = try fileManager.contentsOfDirectory(at: downloadsDirectory, includingPropertiesForKeys: nil)
            let ids = files.compactMap { url -> String? in
                guard url.pathExtension == "mp3" else { return nil }
                return url.deletingPathExtension().lastPathComponent
            }
            self.downloadedSongs = Set(ids)
        } catch {
            self.downloadedSongs = []
        }
    }
    
    private func saveDownloadedSongs() {
        // No-op
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let songId = downloadTask.taskDescription else { return }
        
        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let destDir = documents.appendingPathComponent("Downloads", isDirectory: true)
        let destinationURL = destDir.appendingPathComponent("\(songId).mp3")
        
        do {
            try? fileManager.removeItem(at: destinationURL)
            try fileManager.moveItem(at: location, to: destinationURL)
            
            Task { @MainActor in
                self.finalizeDownload(songId: songId, success: true)
            }
        } catch {
            Task { @MainActor in
                self.finalizeDownload(songId: songId, success: false)
            }
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let songId = downloadTask.taskDescription else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        Task { @MainActor in
            self.updateProgress(songId: songId, progress: progress)
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let songId = task.taskDescription else { return }
        
        if error != nil {
            Task { @MainActor in
                self.finalizeDownload(songId: songId, success: false)
            }
        }
    }
    
    private func updateProgress(songId: String, progress: Double) {
        activeDownloads[songId] = progress
    }
    
    private func finalizeDownload(songId: String, success: Bool) {
        activeDownloads.removeValue(forKey: songId)
        activeTasks.removeValue(forKey: songId)
        
        if success {
            downloadedSongs.insert(songId)
        }
    }
}
