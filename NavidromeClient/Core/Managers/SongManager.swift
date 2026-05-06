import Foundation
import Observation

@MainActor
@Observable
class SongManager {
    private(set) var isLoading = false
    private(set) var error: String?
    
    @ObservationIgnored private weak var service: UnifiedSubsonicService?
    @ObservationIgnored private weak var downloadManager: DownloadManager? // Added
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    // Added configure method for DownloadManager
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
        
        // Fast path: Check offline downloads first
        if let dm = downloadManager, dm.isAlbumDownloaded(albumId) {
            let songs = dm.getSongsForPlayback(albumId: albumId)
            if !songs.isEmpty {
                isLoading = false
                return songs
            }
        }
        
        guard let service = service else {
            isLoading = false
            error = "Service not configured"
            // Fallback: If no service, check downloads one last time
            return downloadManager?.getSongsForPlayback(albumId: albumId) ?? []
        }
        
        do {
            let songs = try await service.getAlbumDetails(id: albumId)
            isLoading = false
            return songs
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            AppLogger.general.error("Failed to load songs: \(error)")
            
            // Network fallback: If network fails, return offline songs if available
            let offlineSongs = downloadManager?.getSongsForPlayback(albumId: albumId) ?? []
            return offlineSongs.isEmpty ? [] : offlineSongs
        }
    }
}
