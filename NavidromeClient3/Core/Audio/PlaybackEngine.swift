//
//  PlaybackEngine.swift
//  NavidromeClient3
//
//  Swift 6: Added 'didUpdateCurrentSongId' to Delegate
//

@preconcurrency import AVFoundation
import MediaPlayer

// MARK: - Delegate Protocol
@MainActor
protocol PlaybackEngineDelegate: AnyObject {
    func playbackEngine(_ engine: PlaybackEngine, didUpdateTime time: Double)
    func playbackEngine(_ engine: PlaybackEngine, didUpdateDuration duration: Double)
    func playbackEngine(_ engine: PlaybackEngine, didChangePlayingState isPlaying: Bool)
    func playbackEngine(_ engine: PlaybackEngine, didFinishPlaying successfully: Bool)
    func playbackEngine(_ engine: PlaybackEngine, didEncounterError error: String)
    func playbackEngineNeedsMoreItems(_ engine: PlaybackEngine)
    
    // NEW: Notify when track changes automatically (Gapless support)
    func playbackEngine(_ engine: PlaybackEngine, didUpdateCurrentSongId songId: String?)
}

@MainActor
final class PlaybackEngine: NSObject {
    static let shared = PlaybackEngine()
    
    // MARK: - Properties
    private var player: AVQueuePlayer
    private var timeObserver: Any?
    
    // Observers
    private var notificationObservers: [NSObjectProtocol] = []
    private var kvoObservers: [NSKeyValueObservation] = []
    
    // Track Item IDs
    private var itemToSongId: [AVPlayerItem: String] = [:]
    private var currentSongId: String?
    
    // Queue Management
    private let queueTargetSize = 3
    
    weak var delegate: PlaybackEngineDelegate?
    
    var rate: Float {
        get { player.rate }
        set { player.rate = newValue }
    }
    
    var duration: Double {
        player.currentItem?.duration.seconds ?? 0
    }
    
    var currentTime: Double {
        player.currentTime().seconds
    }
    
    override init() {
        self.player = AVQueuePlayer()
        super.init()
        setupAudioSession()
        setupTimeObserver()
        setupPlayerObservers()
    }
    
    func cleanup() {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        clearObservers()
        player.removeAllItems()
    }
    
    private func clearObservers() {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
        
        kvoObservers.forEach { $0.invalidate() }
        kvoObservers.removeAll()
    }
    
    private func setupAudioSession() {
        // Handled by AudioSessionManager
    }
    
    // MARK: - Observer Setup
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                self.delegate?.playbackEngine(self, didUpdateTime: time.seconds)
                
                if let duration = self.player.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
                    self.delegate?.playbackEngine(self, didUpdateDuration: duration)
                }
            }
        }
    }
    
    private func setupPlayerObservers() {
        let observer = player.observe(\.currentItem, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                self?.handleCurrentItemChange(player.currentItem)
            }
        }
        kvoObservers.append(observer)
    }
    
    // MARK: - Queue Management
    
    func play(url: URL, songId: String) {
        setQueue(primaryURL: url, primaryId: songId, upcomingURLs: [])
    }
    
    func setQueue(primaryURL: URL, primaryId: String, upcomingURLs: [(String, URL)]) {
        player.pause()
        player.removeAllItems()
        itemToSongId.removeAll()
        
        let primaryItem = createPlayerItem(url: primaryURL, songId: primaryId)
        player.insert(primaryItem, after: nil)
        self.currentSongId = primaryId
        
        for (upcomingId, upcomingUrl) in upcomingURLs.prefix(queueTargetSize) {
            let item = createPlayerItem(url: upcomingUrl, songId: upcomingId)
            player.insert(item, after: player.items().last)
        }
        
        player.play()
        delegate?.playbackEngine(self, didChangePlayingState: true)
        // Explicitly notify delegate of the start
        delegate?.playbackEngine(self, didUpdateCurrentSongId: primaryId)
    }
    
    func appendItem(url: URL, songId: String) {
        let item = createPlayerItem(url: url, songId: songId)
        if player.canInsert(item, after: player.items().last) {
            player.insert(item, after: player.items().last)
        }
    }
    
    func advanceToNextItem() {
        guard player.items().count > 1 else {
            player.advanceToNextItem()
            return
        }
        player.advanceToNextItem()
    }
    
    // MARK: - Controls
    
    func pause() {
        player.pause()
        delegate?.playbackEngine(self, didChangePlayingState: false)
    }
    
    func resume() {
        player.play()
        delegate?.playbackEngine(self, didChangePlayingState: true)
    }
    
    func stop() {
        player.pause()
        player.seek(to: .zero)
        delegate?.playbackEngine(self, didChangePlayingState: false)
    }
    
    func saveCurrentState() {
        AppLogger.general.info("Saving playback state: \(currentSongId ?? "nil") at \(currentTime)")
    }
    
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
        player.seek(to: cmTime)
    }
    
    // MARK: - Private Helpers
    
    private func createPlayerItem(url: URL, songId: String) -> AVPlayerItem {
        let item = AVPlayerItem(url: url)
        itemToSongId[item] = songId
        
        let statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                self?.handleItemStatusChange(item)
            }
        }
        kvoObservers.append(statusObserver)
        
        let finishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor in
                guard let self = self, let item = item else { return }
                self.handleItemDidFinishPlaying(item: item)
            }
        }
        notificationObservers.append(finishObserver)
        
        return item
    }
    
    // MARK: - Event Handlers
    
    private func handleCurrentItemChange(_ newItem: AVPlayerItem?) {
        guard let newItem = newItem else {
            delegate?.playbackEngine(self, didFinishPlaying: true)
            return
        }
        
        if let songId = itemToSongId[newItem] {
            currentSongId = songId
            // Notify delegate that the track has changed
            delegate?.playbackEngine(self, didUpdateCurrentSongId: songId)
        }
        
        pruneOldItems()
        checkAndRequestMoreItems()
    }
    
    private func handleItemDidFinishPlaying(item: AVPlayerItem) {
        // AVQueuePlayer moves to next automatically.
    }
    
    private func handleItemStatusChange(_ item: AVPlayerItem) {
        if item.status == .failed, let error = item.error {
            delegate?.playbackEngine(self, didEncounterError: error.localizedDescription)
        }
    }
    
    private func checkAndRequestMoreItems() {
        if player.items().count <= queueTargetSize {
            delegate?.playbackEngineNeedsMoreItems(self)
        }
    }
    
    private func pruneOldItems() {
        let currentItems = Set(player.items())
        let mappedItems = Array(itemToSongId.keys)
        
        for item in mappedItems {
            if !currentItems.contains(item) {
                itemToSongId.removeValue(forKey: item)
            }
        }
    }
}
