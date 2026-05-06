//
//  DownloadManager.swift
//  NavidromeClient
//
//  REFACTORED: Step 5 — Managers
//  MainActor holds only observable UI state.
//  All URLSession, FileManager, and Data I/O moved off MainActor.
//

import Foundation
import Observation

@MainActor
@Observable
class DownloadManager {
    static let shared = DownloadManager()

    private(set) var downloadedAlbums: [DownloadedAlbum] = []
    private(set) var downloadedSongs: Set<String> = []
    private(set) var isDownloading: Set<String> = []
    private(set) var downloadProgress: [String: Double] = [:]
    private(set) var downloadStates: [String: DownloadState] = [:]
    private(set) var downloadErrors: [String: String] = [:]

    @ObservationIgnored private weak var service: UnifiedSubsonicService?
    @ObservationIgnored private weak var coverArtManager: CoverArtManager?
    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []

    // STEP 5: Storage actor owns all disk I/O
    @ObservationIgnored private let storage = AppStorageActor.shared

    enum DownloadState: Equatable, Sendable {
        case idle, downloading, downloaded, cancelling
        case error(String)

        var isLoading: Bool {
            switch self { case .downloading, .cancelling: return true; default: return false }
        }
        var canStartDownload: Bool {
            switch self { case .idle, .error: return true; default: return false }
        }
        var canCancel: Bool { self == .downloading }
        var canDelete: Bool { self == .downloaded }
    }

    init() {
        Task { await loadDownloadedAlbumsFromDisk() }
        setupStateObservation()
    }

    deinit {
        observationTasks.forEach { $0.cancel() }
    }

    // MARK: - Configuration

    func configure(service: UnifiedSubsonicService) { self.service = service }
    func configure(coverArtManager: CoverArtManager) { self.coverArtManager = coverArtManager }

    // MARK: - Download

    func startDownload(album: Album, songs: [Song]) async {
        guard getDownloadState(for: album.id).canStartDownload else { return }
        guard let service else {
            let msg = "Service not available"
            downloadErrors[album.id] = msg
            setDownloadState(.error(msg), for: album.id)
            return
        }

        await AlbumMetadataCache.shared.cacheAlbum(album)
        setDownloadState(.downloading, for: album.id)
        downloadErrors.removeValue(forKey: album.id)

        do {
            try await downloadAlbum(songs: songs, album: album, service: service)
            setDownloadState(.downloaded, for: album.id)
            NotificationCenter.default.post(name: .downloadCompleted, object: album.id)
        } catch {
            let msg = "Download failed: \(error.localizedDescription)"
            downloadErrors[album.id] = msg
            setDownloadState(.error(msg), for: album.id)
            NotificationCenter.default.post(name: .downloadFailed, object: album.id,
                                            userInfo: ["error": error])
        }
    }

    // MARK: - Core download (all heavy work off MainActor)

    private func downloadAlbum(
        songs: [Song],
        album: Album,
        service: UnifiedSubsonicService
    ) async throws {
        let albumId = album.id
        guard !isDownloading.contains(albumId) else { throw DownloadError.alreadyInProgress }
        guard let albumMeta = await AlbumMetadataCache.shared.getAlbum(id: albumId)
        else { throw DownloadError.missingMetadata }

        isDownloading.insert(albumId)
        downloadProgress[albumId] = 0

        // STEP 5: folder creation via StorageActor
        let albumFolder = downloadsFolder.appendingPathComponent(albumId, isDirectory: true)
        await storage.createDirectory(at: albumFolder)

        var downloadedSongsMeta: [DownloadedSong] = []
        let total = songs.count
        let downloadDate = Date()

        await downloadAlbumCoverArt(album: albumMeta)
        await downloadArtistImage(for: albumMeta)

        for (index, song) in songs.enumerated() {
            guard let streamURL = service.streamURL(for: song.id) else { continue }

            let sanitized = sanitizeFileName(song.title)
            let track = String(format: "%02d", song.track ?? index + 1)
            let fileName = "\(track) - \(sanitized).mp3"
            let fileURL = albumFolder.appendingPathComponent(fileName)

            do {
                // STEP 5: URLSession call in a detached task — off MainActor
                let (data, response) = try await Task.detached(priority: .medium) {
                    try await URLSession.shared.data(from: streamURL)
                }.value

                if let http = response as? HTTPURLResponse, http.statusCode != 200 { continue }

                // STEP 5: file write via StorageActor
                try await storage.writeSongFile(data: data, to: fileURL)

                downloadedSongsMeta.append(DownloadedSong(
                    id: song.id, title: song.title, artist: song.artist,
                    album: song.album, albumId: song.albumId, track: song.track,
                    duration: song.duration, year: song.year, genre: song.genre,
                    contentType: song.contentType, fileName: fileName,
                    fileSize: Int64(data.count), downloadDate: downloadDate
                ))
                downloadedSongs.insert(song.id)
                downloadProgress[albumId] = Double(index + 1) / Double(total)
            } catch {
                throw DownloadError.songDownloadFailed(song.title, error)
            }
        }

        if !downloadedSongsMeta.isEmpty {
            let da = DownloadedAlbum(
                albumId: albumId, albumName: albumMeta.name, artistName: albumMeta.artist,
                year: albumMeta.year, genre: albumMeta.genre,
                songs: downloadedSongsMeta, downloadDate: downloadDate
            )
            if let i = downloadedAlbums.firstIndex(where: { $0.albumId == albumId }) {
                downloadedAlbums[i] = da
            } else {
                downloadedAlbums.append(da)
            }
            await persistDownloadedAlbums()
        }

        isDownloading.remove(albumId)
        downloadProgress[albumId] = 1.0
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        downloadProgress.removeValue(forKey: albumId)
    }

    // MARK: - Persistence (all via StorageActor)

    private func loadDownloadedAlbumsFromDisk() async {
        let albums = await storage.loadDownloadedAlbums()
        downloadedAlbums = albums
        rebuildDownloadedSongsSet()
        for album in albums { updateDownloadState(for: album.albumId) }
    }

    private func persistDownloadedAlbums() async {
        let snapshot = downloadedAlbums
        await storage.saveDownloadedAlbums(snapshot)
    }

    // MARK: - Cover art (unchanged, delegates to CoverArtManager)

    private func downloadAlbumCoverArt(album: Album) async {
        guard let cam = coverArtManager else { return }
        await withTaskGroup(of: Void.self) { group in
            for ctx in [ImageContext.list, .card, .grid] {
                group.addTask { _ = await cam.loadAlbumImage(album: album, context: ctx) }
            }
        }
    }

    private func downloadArtistImage(for album: Album) async {
        guard let cam = coverArtManager else { return }
        let artist = Artist(id: album.artistId ?? "artist_\(album.artist.hash)",
                            name: album.artist, coverArt: album.coverArt,
                            albumCount: 1, artistImageUrl: nil)
        await withTaskGroup(of: Void.self) { group in
            for ctx in [ImageContext.artistList, .artistCard] {
                group.addTask { _ = await cam.loadArtistImage(artist: artist, context: ctx) }
            }
        }
    }

    // MARK: - Delete

    func deleteAlbum(albumId: String) {
        guard getDownloadState(for: albumId).canDelete else { return }
        let albumFolder = downloadsFolder.appendingPathComponent(albumId, isDirectory: true)
        Task { await storage.deleteFolder(at: albumFolder) }

        if let album = downloadedAlbums.first(where: { $0.albumId == albumId }) {
            album.songs.forEach { downloadedSongs.remove($0.id) }
        }
        downloadedAlbums.removeAll { $0.albumId == albumId }
        downloadProgress.removeValue(forKey: albumId)
        isDownloading.remove(albumId)
        downloadStates.removeValue(forKey: albumId)
        downloadErrors.removeValue(forKey: albumId)

        Task { await persistDownloadedAlbums() }
        NotificationCenter.default.post(name: .downloadDeleted, object: albumId)
    }

    func deleteAllDownloads() {
        Task { await storage.deleteFolder(at: downloadsFolder) }
        Task { await storage.createDirectory(at: downloadsFolder) }
        downloadedAlbums.removeAll()
        downloadedSongs.removeAll()
        downloadProgress.removeAll()
        isDownloading.removeAll()
        downloadStates.removeAll()
        downloadErrors.removeAll()
        Task { await persistDownloadedAlbums() }
    }

    func deleteDownload(albumId: String) {
        guard getDownloadState(for: albumId).canDelete else { return }
        deleteAlbum(albumId: albumId)
        setDownloadState(.idle, for: albumId)
        downloadErrors.removeValue(forKey: albumId)
    }

    func cancelDownload(albumId: String) {
        guard getDownloadState(for: albumId).canCancel else { return }
        setDownloadState(.cancelling, for: albumId)
        isDownloading.remove(albumId)
        downloadProgress.removeValue(forKey: albumId)
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            setDownloadState(.idle, for: albumId)
        }
    }

    // MARK: - State

    func getDownloadState(for albumId: String) -> DownloadState {
        downloadStates[albumId] ?? determineDownloadState(for: albumId)
    }
    private func setDownloadState(_ state: DownloadState, for albumId: String) {
        downloadStates[albumId] = state
    }
    private func updateDownloadState(for albumId: String) {
        setDownloadState(determineDownloadState(for: albumId), for: albumId)
    }
    private func determineDownloadState(for albumId: String) -> DownloadState {
        if isAlbumDownloaded(albumId) { return .downloaded }
        if isAlbumDownloading(albumId) { return .downloading }
        if let e = downloadErrors[albumId] { return .error(e) }
        return .idle
    }

    // MARK: - Queries

    func isAlbumDownloaded(_ albumId: String) -> Bool { downloadedAlbums.contains { $0.albumId == albumId } }
    func isAlbumDownloading(_ albumId: String) -> Bool { isDownloading.contains(albumId) }
    func isSongDownloaded(_ songId: String) -> Bool { downloadedSongs.contains(songId) }

    func getDownloadedSong(_ songId: String) -> DownloadedSong? {
        downloadedAlbums.flatMap { $0.songs }.first { $0.id == songId }
    }
    func getDownloadedSongs(for albumId: String) -> [DownloadedSong] {
        downloadedAlbums.first { $0.albumId == albumId }?.songs ?? []
    }
    func getSongsForPlayback(albumId: String) -> [Song] {
        getDownloadedSongs(for: albumId).map { $0.toSong() }
    }

    func getLocalFileURL(for songId: String) -> URL? {
        guard let song = getDownloadedSong(songId) else { return nil }
        for album in downloadedAlbums where album.songs.contains(where: { $0.id == songId }) {
            let url = URL(fileURLWithPath: album.folderPath).appendingPathComponent(song.fileName)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    func totalDownloadSize() -> String {
        let bytes = downloadedAlbums.reduce(0) { $0 + $1.songs.reduce(0) { $0 + $1.fileSize } }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576.0)
    }

    // MARK: - Private helpers

    private var downloadsFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
    }

    private func rebuildDownloadedSongsSet() {
        downloadedSongs = Set(downloadedAlbums.flatMap { $0.songs.map { $0.id } })
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name.components(separatedBy: invalid).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(50).description
    }

    private func setupStateObservation() {
        let center = NotificationCenter.default
        observationTasks.append(Task { [weak self] in
            for await n in center.notifications(named: .downloadCompleted) {
                guard let self, let id = n.object as? String else { continue }
                await MainActor.run { self.updateDownloadState(for: id) }
            }
        })
        observationTasks.append(Task { [weak self] in
            for await n in center.notifications(named: .downloadFailed) {
                guard let self, let id = n.object as? String else { continue }
                await MainActor.run { self.downloadStates[id] = .error("Download failed") }
            }
        })
        observationTasks.append(Task { [weak self] in
            for await _ in center.notifications(named: .factoryResetRequested) {
                guard let self else { return }
                await MainActor.run { self.deleteAllDownloads() }
            }
        })
    }

    // MARK: - Error types

    enum DownloadError: LocalizedError {
        case alreadyInProgress, missingMetadata
        case folderCreationFailed(Error), songDownloadFailed(String, Error)
        case noSongsDownloaded, serviceUnavailable

        var errorDescription: String? {
            switch self {
            case .alreadyInProgress: return "Download already in progress"
            case .missingMetadata: return "Album metadata not found"
            case .folderCreationFailed(let e): return "Failed to create folder: \(e.localizedDescription)"
            case .songDownloadFailed(let t, let e): return "Failed to download '\(t)': \(e.localizedDescription)"
            case .noSongsDownloaded: return "No songs were successfully downloaded"
            case .serviceUnavailable: return "Service not available"
            }
        }
    }

    // MARK: - Diagnostics

    func getServiceDiagnostics() -> DownloadServiceDiagnostics {
        DownloadServiceDiagnostics(hasService: service != nil, hasCoverArtManager: coverArtManager != nil,
                                   activeDownloads: isDownloading.count, totalDownloads: downloadedAlbums.count,
                                   errorCount: downloadErrors.count)
    }

    struct DownloadServiceDiagnostics {
        let hasService: Bool; let hasCoverArtManager: Bool
        let activeDownloads: Int; let totalDownloads: Int; let errorCount: Int
        var healthScore: Double {
            var s = 0.0
            if hasService { s += 0.5 }; if hasCoverArtManager { s += 0.3 }
            if activeDownloads < 5 { s += 0.1 }; if errorCount < 3 { s += 0.1 }
            return min(s, 1.0)
        }
    }
}
