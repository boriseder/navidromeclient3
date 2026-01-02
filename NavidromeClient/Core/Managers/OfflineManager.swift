//
//  OfflineManager.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Observable
//

import Foundation
import Observation

@MainActor
@Observable
class OfflineManager {
    static let shared = OfflineManager()
    
    private(set) var isOfflineMode = false
    private(set) var offlineAlbums: [Album] = []
    
    init() {
        setupFactoryResetObserver()
    }
    
    // MARK: - Mode Control
    
    func toggleOfflineMode() {
        isOfflineMode.toggle()
        
        if isOfflineMode {
            AppLogger.general.info("[OfflineManager] Switched to Offline Mode")
            refreshOfflineContent()
        } else {
            AppLogger.general.info("[OfflineManager] Switched to Online Mode")
        }
        
        NotificationCenter.default.post(name: .contentLoadingStrategyChanged, object: nil)
    }
    
    func setOfflineMode(_ enabled: Bool) {
        guard isOfflineMode != enabled else { return }
        
        isOfflineMode = enabled
        if isOfflineMode {
            refreshOfflineContent()
        }
        NotificationCenter.default.post(name: .contentLoadingStrategyChanged, object: nil)
    }
    
    // MARK: - Content Management
    
    func refreshOfflineContent() {
        let downloaded = DownloadManager.shared.downloadedAlbums
        
        self.offlineAlbums = downloaded.map { dl in
            Album(
                id: dl.albumId,
                parent: nil,
                album: dl.albumName,
                title: dl.albumName,
                name: dl.albumName,
                isDir: true,
                coverArt: dl.albumId,
                artist: dl.artistName,
                artistId: nil,
                created: dl.downloadDate,
                duration: dl.songs.reduce(0) { $0 + ($1.duration ?? 0) },
                playCount: 0,
                songCount: dl.songs.count,
                year: dl.year,
                genre: dl.genre
            )
        }.sorted { $0.name < $1.name }
        
        AppLogger.general.info("[OfflineManager] Refreshed offline content: \(offlineAlbums.count) albums")
    }
    
    // MARK: - Data Access
    
    func getOfflineAlbums(for artist: Artist) -> [Album] {
        return offlineAlbums.filter { $0.artist == artist.name }
    }
    
    func getOfflineAlbums(for genre: Genre) -> [Album] {
        guard let genreName = genre.value.first?.description else { return [] }
        return offlineAlbums.filter { $0.genre?.contains(genreName) == true }
    }
    
    // MARK: - Reset
    
    func performCompleteReset() {
        isOfflineMode = false
        offlineAlbums.removeAll()
        AppLogger.general.info("[OfflineManager] Reset complete")
    }
    
    private func setupFactoryResetObserver() {
        NotificationCenter.default.addObserver(
            forName: .factoryResetRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.performCompleteReset()
            }
        }
    }
}
