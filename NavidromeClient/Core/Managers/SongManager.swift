//
//  SongManager.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - FIXED: Strictly uses @Observable
//  - FIXED Bug 02: loadSongs now checks DownloadManager for offline songs
//    before hitting the network, and falls back to downloaded songs when the
//    network call fails or the service is unavailable.
//

import Foundation
import Observation

@MainActor
@Observable
class SongManager {
    private(set) var isLoading = false
    private(set) var error: String?
    
    @ObservationIgnored private weak var service: UnifiedSubsonicService?
    @ObservationIgnored private weak var downloadManager: DownloadManager?
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    // Called by AppInitializer.configureManagers alongside the service.
    func configure(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager
    }
    
    func reset() {
        error = nil
        isLoading = false
    }
    
    func loadSongs(for albumId: String) async -> [Song] {
        isLoading = true
        error = nil
        
        // ── Offline fast path ────────────────────────────────────────────────
        // If the album is already downloaded, return those songs immediately
        // without touching the network. This is the fix for Bug 02: previously
        // this method returned [] when offline even though the songs were on
        // disk, because it only knew how to call getAlbumDetails on the service.
        if let dm = downloadManager, dm.isAlbumDownloaded(albumId) {
            let offlineSongs = dm.getSongsForPlayback(albumId: albumId)
            if !offlineSongs.isEmpty {
                AppLogger.general.info("SongManager: Returning \(offlineSongs.count) offline songs for album \(albumId)")
                isLoading = false
                return offlineSongs
            }
            // Downloaded flag is set but no songs decoded (corrupt data) —
            // fall through to the network attempt below.
            AppLogger.general.warn("SongManager: Album \(albumId) marked downloaded but no songs decoded — attempting network fetch")
        }
        
        // ── Network path ─────────────────────────────────────────────────────
        guard let service = service else {
            isLoading = false
            error = "Service not configured"
            // Last-resort: return whatever is on disk even if isAlbumDownloaded
            // returned false (handles edge cases where the download state is
            // out of sync with the actual files).
            let fallback = downloadManager?.getSongsForPlayback(albumId: albumId) ?? []
            if !fallback.isEmpty {
                AppLogger.general.info("SongManager: No service — using \(fallback.count) cached songs for album \(albumId)")
            }
            return fallback
        }
        
        do {
            let songs = try await service.getAlbumDetails(id: albumId)
            isLoading = false
            return songs
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            AppLogger.general.error("SongManager: Network fetch failed for album \(albumId): \(error)")
            
            // Network failed — return downloaded songs if available so the
            // album detail view shows something rather than a blank list.
            let fallback = downloadManager?.getSongsForPlayback(albumId: albumId) ?? []
            if !fallback.isEmpty {
                AppLogger.general.info("SongManager: Network failed — using \(fallback.count) downloaded songs for album \(albumId)")
            }
            return fallback
        }
    }
}
