//
//  StorageActor.swift
//  NavidromeClient
//
//  Created by Boris Eder on 03.05.26.
//


//
//  StorageActor.swift
//  NavidromeClient
//
//  NEW: Swift 6 Concurrency Refactoring — Step 1
//  Owns ALL disk I/O. No network. No UI.
//  All public methods are isolated to this actor.
//

import Foundation
import UIKit
import CryptoKit

// MARK: - StorageActor

actor StorageActor {

    // MARK: - Directories

    private let imagesCacheDirectory: URL
    private let documentsDirectory: URL
    
    // Add to StorageActor
    var imageCacheDirectory: URL { imagesCacheDirectory }

    // MARK: - Initialisation

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let caches = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CoverArtCache", isDirectory: true)

        self.documentsDirectory = docs
        self.imagesCacheDirectory = caches

        // Synchronous directory creation is fine here: actor init runs once,
        // not on the MainActor, so it does not block the UI.
        try? FileManager.default.createDirectory(
            at: imagesCacheDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Image Cache

    func saveImage(data: Data, key: String, size: Int) {
        let url = imageURL(for: key, size: size)
        try? data.write(to: url, options: .atomic)
    }

    func loadImage(key: String, size: Int) -> Data? {
        let url = imageURL(for: key, size: size)
        return try? Data(contentsOf: url)
    }

    func createDirectory(at url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func deleteImage(key: String, size: Int) {
        let url = imageURL(for: key, size: size)
        try? FileManager.default.removeItem(at: url)
    }

    func clearImageCache() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: imagesCacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        for file in contents {
            try? fm.removeItem(at: file)
        }
    }

    /// Returns the total size in bytes of the image cache directory.
    func imageCacheDiskSize() -> Int64 {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: imagesCacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        return contents.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }

    func imageCacheFileCount() -> Int {
        let fm = FileManager.default
        return (try? fm.contentsOfDirectory(
            at: imagesCacheDirectory,
            includingPropertiesForKeys: nil
        ).count) ?? 0
    }

    // MARK: - Image Cache Metadata

    private let metadataFileName = "metadata.json"

    func saveImageMetadata(_ metadata: [String: PersistentImageCache.CacheMetadata]) {
        let url = imagesCacheDirectory.appendingPathComponent(metadataFileName)
        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func loadImageMetadata() -> [String: PersistentImageCache.CacheMetadata] {
        let url = imagesCacheDirectory.appendingPathComponent(metadataFileName)
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: PersistentImageCache.CacheMetadata].self, from: data)) ?? [:]
    }

    func removeOrphanedImageFiles(knownFilenames: Set<String>) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: imagesCacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in contents {
            let name = fileURL.lastPathComponent
            guard name != metadataFileName else { continue }
            if !knownFilenames.contains(name) {
                try? fm.removeItem(at: fileURL)
            }
        }
    }

    func deleteFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Albums JSON Persistence

    private var albumsFileURL: URL {
        documentsDirectory.appendingPathComponent("album_metadata_cache.json")
    }

    func saveAlbums(_ albums: [String: Album]) {
        if let data = try? JSONEncoder().encode(albums) {
            try? data.write(to: albumsFileURL, options: .atomic)
        }
    }

    func loadAlbums() -> [String: Album] {
        guard FileManager.default.fileExists(atPath: albumsFileURL.path),
              let data = try? Data(contentsOf: albumsFileURL) else { return [:] }
        return (try? JSONDecoder().decode([String: Album].self, from: data)) ?? [:]
    }

    func clearAlbumsFile() {
        try? FileManager.default.removeItem(at: albumsFileURL)
    }

    // MARK: - Downloaded Albums JSON Persistence

    private var downloadedAlbumsFileURL: URL {
        downloadsFolder.appendingPathComponent("downloaded_albums.json")
    }

    private var downloadsFolder: URL {
        let folder = documentsDirectory.appendingPathComponent("Downloads", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    func saveDownloadedAlbums(_ albums: [DownloadedAlbum]) {
        if let data = try? JSONEncoder().encode(albums) {
            try? data.write(to: downloadedAlbumsFileURL, options: .atomic)
        }
    }

    func loadDownloadedAlbums() -> [DownloadedAlbum] {
        guard FileManager.default.fileExists(atPath: downloadedAlbumsFileURL.path),
              let data = try? Data(contentsOf: downloadedAlbumsFileURL) else { return [] }
        return (try? JSONDecoder().decode([DownloadedAlbum].self, from: data)) ?? []
    }

    // MARK: - Song File I/O

    func writeSongFile(data: Data, to url: URL) throws {
        // Ensure parent directory exists
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    func deleteFolder(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Private Helpers

    private func imageURL(for key: String, size: Int) -> URL {
        let hashed = key.storageSHA256()
        return imagesCacheDirectory.appendingPathComponent("\(hashed)_\(size).jpg")
    }
}

// MARK: - String SHA-256 helper (file-private to this module boundary)

extension String {
    /// Returns a hex SHA-256 of the string. Used for stable file names.
    func storageSHA256() -> String {
        let data = Data(self.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
