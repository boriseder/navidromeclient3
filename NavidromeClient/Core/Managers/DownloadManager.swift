//
//  DownloadManager.swift - FIXED: Reactive State Management
//  NavidromeClient
//
//  FIXED: Strict Concurrency compliance for Init and I/O
//

import Foundation

@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var downloadedAlbums: [DownloadedAlbum] = []
    @Published private(set) var downloadedSongs: Set<String> = []
    @Published private(set) var isDownloading: Set<String> = []
    @Published private(set) var downloadProgress: [String: Double] = [:]
    
    @Published private(set) var downloadStates: [String: DownloadState] = [:]
    @Published private(set) var downloadErrors: [String: String] = [:]

    private weak var service: UnifiedSubsonicService?
    private weak var coverArtManager: CoverArtManager?

    // Properties for paths
    private var downloadsFolder: URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private var downloadedAlbumsFile: URL {
        downloadsFolder.appendingPathComponent("downloaded_albums.json")
    }

    enum DownloadState: Equatable {
        case idle
        case downloading
        case downloaded
        case error(String)
        case cancelling
        
        var isLoading: Bool {
            switch self {
            case .downloading, .cancelling: return true
            default: return false
            }
        }
        
        var canStartDownload: Bool {
            switch self {
            case .idle, .error: return true
            default: return false
            }
        }
        
        var canCancel: Bool {
            return self == .downloading
        }
        
        var canDelete: Bool {
            return self == .downloaded
        }
    }

    // Swift 6: Explicit MainActor init ensures @Published properties can be set safely
    init() {
        loadDownloadedAlbums()
        migrateOldDataIfNeeded()
        setupStateObservation()
    }
    
    // MARK: - Service Configuration
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    func configure(coverArtManager: CoverArtManager) {
        self.coverArtManager = coverArtManager
    }
    
    // MARK: - Download Operations
    
    func startDownload(album: Album, songs: [Song]) async {
        guard getDownloadState(for: album.id).canStartDownload else {
            AppLogger.general.error("Cannot start download for album \(album.id) in current state")
            return
        }
        
        guard let service = service else {
            let errorMessage = "Service not available for downloads"
            downloadErrors[album.id] = errorMessage
            setDownloadState(.error(errorMessage), for: album.id)
            AppLogger.general.error("[DownloadManager] UnifiedSubsonicService not configured for DownloadManager")
            return
        }
        
        AlbumMetadataCache.shared.cacheAlbum(album)
        AppLogger.general.info("Cached album metadata for download: \(album.name) (ID: \(album.id))")
        
        setDownloadState(.downloading, for: album.id)
        downloadErrors.removeValue(forKey: album.id)
        
        do {
            try await downloadAlbumWithService(
                songs: songs,
                albumId: album.id,
                service: service
            )
            setDownloadState(.downloaded, for: album.id)
            
            NotificationCenter.default.post(name: .downloadCompleted, object: album.id)
            
        } catch {
            let errorMessage = "Download failed: \(error.localizedDescription)"
            downloadErrors[album.id] = errorMessage
            setDownloadState(.error(errorMessage), for: album.id)
            
            AppLogger.general.error("Download failed for album \(album.id): \(error)")
            
            NotificationCenter.default.post(
                name: .downloadFailed,
                object: album.id,
                userInfo: ["error": error]
            )
        }
    }
    
    // MARK: - Core Download Implementation
    
    private func downloadAlbumWithService(
        songs: [Song],
        albumId: String,
        service: UnifiedSubsonicService
    ) async throws {
        
        guard !isDownloading.contains(albumId) else {
            throw DownloadError.alreadyInProgress
        }
        
        guard let albumMetadata = AlbumMetadataCache.shared.getAlbum(id: albumId) else {
            throw DownloadError.missingMetadata
        }
        
        AppLogger.general.info("Starting download of album '\(albumMetadata.name)' with \(songs.count) songs")
        
        isDownloading.insert(albumId)
        downloadProgress[albumId] = 0

        let albumFolder = downloadsFolder.appendingPathComponent(albumId, isDirectory: true)
        if !FileManager.default.fileExists(atPath: albumFolder.path) {
            do {
                try FileManager.default.createDirectory(at: albumFolder, withIntermediateDirectories: true)
            } catch {
                isDownloading.remove(albumId)
                downloadProgress.removeValue(forKey: albumId)
                throw DownloadError.folderCreationFailed(error)
            }
        }

        var downloadedSongsMetadata: [DownloadedSong] = []
        let totalSongs = songs.count
        let downloadDate = Date()

        await downloadAlbumCoverArt(album: albumMetadata)
        await downloadArtistImage(for: albumMetadata)

        for (index, song) in songs.enumerated() {
            guard let streamURL = getStreamURL(for: song.id, from: service) else {
                AppLogger.general.error("No stream URL for song: \(song.title)")
                continue
            }
            
            let sanitizedTitle = sanitizeFileName(song.title)
            let trackNumber = String(format: "%02d", song.track ?? index + 1)
            let fileName = "\(trackNumber) - \(sanitizedTitle).mp3"
            let fileURL = albumFolder.appendingPathComponent(fileName)

            do {
                AppLogger.general.info("Downloading: \(song.title)")
                // URLSession is implicitly nonisolated/thread-safe
                let (data, response) = try await URLSession.shared.data(from: streamURL)
                
                if let httpResponse = response as? HTTPURLResponse {
                    guard httpResponse.statusCode == 200 else {
                        AppLogger.general.error("Download failed for \(song.title): HTTP \(httpResponse.statusCode)")
                        continue
                    }
                }
                
                // Swift 6 Optimization: Offload file write to detached task to avoid blocking MainActor
                try await saveFile(data: data, to: fileURL)

                let downloadedSong = DownloadedSong(
                    id: song.id,
                    title: song.title,
                    artist: song.artist,
                    album: song.album,
                    albumId: song.albumId,
                    track: song.track,
                    duration: song.duration,
                    year: song.year,
                    genre: song.genre,
                    contentType: song.contentType,
                    fileName: fileName,
                    fileSize: Int64(data.count),
                    downloadDate: downloadDate
                )
                
                downloadedSongsMetadata.append(downloadedSong)
                downloadedSongs.insert(song.id)
                
                downloadProgress[albumId] = Double(index + 1) / Double(totalSongs)
            } catch {
                AppLogger.general.error("Download error for \(song.title): \(error)")
                throw DownloadError.songDownloadFailed(song.title, error)
            }
        }

        if !downloadedSongsMetadata.isEmpty {
            let downloadedAlbum = DownloadedAlbum(
                albumId: albumId,
                albumName: albumMetadata.name,
                artistName: albumMetadata.artist,
                year: albumMetadata.year,
                genre: albumMetadata.genre,
                songs: downloadedSongsMetadata,
                downloadDate: downloadDate
                // Remove folderPath parameter
            )
            
            if let existingIndex = downloadedAlbums.firstIndex(where: { $0.albumId == albumId }) {
                downloadedAlbums[existingIndex] = downloadedAlbum
            } else {
                downloadedAlbums.append(downloadedAlbum)
            }

            saveDownloadedAlbums()
        }

        isDownloading.remove(albumId)
        downloadProgress[albumId] = 1.0

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        downloadProgress.removeValue(forKey: albumId)
    }
    
    // Swift 6: Helper to offload blocking I/O
    private nonisolated func saveFile(data: Data, to url: URL) async throws {
        try await Task.detached(priority: .medium) {
            try data.write(to: url, options: .atomic)
        }.value
    }
    
    // MARK: - Cover Art Integration (Unchanged)
    
    private func downloadAlbumCoverArt(album: Album) async {
        guard let coverArtManager = coverArtManager else {
            AppLogger.general.error("CoverArtManager not configured - skipping cover art")
            return
        }
        
        let contexts: [ImageContext] = [.list, .card, .grid]
        
        await withTaskGroup(of: Void.self) { group in
            for context in contexts {
                group.addTask {
                    _ = await coverArtManager.loadAlbumImage(album: album, context: context)
                }
            }
        }
    }
    
    private func downloadArtistImage(for album: Album) async {
        guard let coverArtManager = coverArtManager else {
            AppLogger.general.info("CoverArtManager not configured - skipping artist image")
            return
        }
        
        let artist = Artist(
            id: album.artistId ?? "artist_\(album.artist.hash)",
            name: album.artist,
            coverArt: album.coverArt,
            albumCount: 1,
            artistImageUrl: nil
        )
        
        let contexts: [ImageContext] = [.artistList, .artistCard]
        
        await withTaskGroup(of: Void.self) { group in
            for context in contexts {
                group.addTask {
                    _ = await coverArtManager.loadArtistImage(artist: artist, context: context)
                }
            }
        }
    }
    
    // MARK: - Stream URL Resolution
    
    private func getStreamURL(for songId: String, from service: UnifiedSubsonicService) -> URL? {
        guard !songId.isEmpty else { return nil }
        return service.streamURL(for: songId)
    }

    // MARK: - UI State Management
    
    private func setupStateObservation() {
