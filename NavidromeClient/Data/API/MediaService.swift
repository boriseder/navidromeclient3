//
//  MediaService.swift
//  NavidromeClient
//
//  REFACTORED: Step 2 — NetworkActor
//

import Foundation
import UIKit

final class MediaService: Sendable {

    private let network: NetworkActor

    init(network: NetworkActor) {
        self.network = network
    }

    // NOTE: Does NOT write to PersistentImageCache here.
    // CoverArtManager.fetchFromNetwork() stores the result via ImageCacheActor
    // (memory + disk). Writing here too would double every disk write and
    // trigger two metadata-save debounce resets per image.
    func getCoverArt(for coverId: String, size: Int = 300) async -> UIImage? {
        do {
            let data = try await network.fetchRawData(
                endpoint: "getCoverArt",
                params: ["id": coverId, "size": "\(size)"]
            )
            return UIImage(data: data)
        } catch {
            AppLogger.ui.error("❌ Cover art load error: \(error)")
            return nil
        }
    }

    nonisolated func streamURL(for songId: String) -> URL? {
        network.streamURL(for: songId)
    }

    nonisolated func downloadURL(for songId: String, maxBitRate: Int? = nil) -> URL? {
        guard !songId.isEmpty else { return nil }
        var params = ["id": songId]
        if let bitRate = maxBitRate { params["maxBitRate"] = "\(bitRate)" }
        return network.buildURL(endpoint: "download", params: params)
    }
}

struct MediaInfo { let bitRate: Int?; let format: String?; let duration: TimeInterval?; let fileSize: Int64? }

struct MediaCacheStats {
    let imageCount: Int; let cacheSize: Int64; let activeRequests: Int
    var cacheSizeFormatted: String { ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file) }
    var summary: String { "Images: \(imageCount), Size: \(cacheSizeFormatted), Active: \(activeRequests)" }
}
