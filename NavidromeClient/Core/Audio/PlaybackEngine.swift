//
//  PlaybackEngine.swift
//  NavidromeClient
//
//  FIXED Bug 16: statusObservers changed from [Task] array to
//  [ObjectIdentifier: Task] dictionary. This ensures:
//    - Each AVPlayerItem has exactly one status observer task at a time.
//    - When an item is unregistered (song finishes / queue cleared), its
//      task is cancelled immediately rather than accumulating indefinitely.
//    - cleanupQueue() still cancels everything in one sweep.
//
//  Previously the array grew by one entry per registered item and was only
//  fully cleared in cleanupQueue(). Between songs — while new items were
//  added and old items finished — dead tasks piled up, each holding a live
//  AsyncStream that kept a KVO observation on a dead AVPlayerItem alive.
//

@preconcurrency import Foundation
import AVFoundation

// MARK: - PlaybackEngineDelegate Protocol

@MainActor
protocol PlaybackEngineDelegate: AnyObject {
    func playbackEngine(_ engine: PlaybackEngine, didUpdateTime time: TimeInterval)
    func playbackEngine(_ engine: PlaybackEngine, didUpdateDuration duration: TimeInterval)
    func playbackEngine(_ engine: PlaybackEngine, didChangePlayingState isPlaying: Bool)
    func playbackEngine(_ engine: PlaybackEngine, didFinishPlaying successfully: Bool)
    func playbackEngine(_ engine: PlaybackEngine, didEncounterError error: String)
    func playbackEngine(_ engine: PlaybackEngine, didAdvanceToSongId songId: String)
    func playbackEngineNeedsMoreItems(_ engine: PlaybackEngine) async
}

// MARK: - PlaybackEngine

@MainActor
class PlaybackEngine {
    
    // MARK: - Properties
    
    private let queuePlayer = AVQueuePlayer()
    
    private var itemToSongId: [ObjectIdentifier: String] = [:]
    private var songIdToItem: [String: AVPlayerItem] = [:]
    
    private var currentSongId: String?
    private var timeObserver: Any?
    private var currentItemObserver: NSKeyValueObservation?

    private let queueTargetSize = 3
    private var isExtendingQueue = false
    
    nonisolated(unsafe) private var itemObservers: [NSObjectProtocol] = []

    // FIXED Bug 16: was [Task<Void, Never>] — grew unbounded because tasks
    // were only removed en-masse in cleanupQueue(). Now keyed by the item's
    // ObjectIdentifier so unregisterItem() can cancel exactly the one task
    // that belongs to the departing item, keeping the dictionary at the same
    // size as the live item set.
    nonisolated(unsafe) private var statusObservers: [ObjectIdentifier: Task<Void, Never>] = [:]

    var currentQueueSize: Int {
        queuePlayer.items().count
    }

    weak var delegate: PlaybackEngineDelegate?
    
    var volume: Float {
        get { queuePlayer.volume }
        set { queuePlayer.volume = newValue }
    }
    
    var currentTime: TimeInterval {
        queuePlayer.currentTime().seconds
    }
    
    var duration: TimeInterval {
        queuePlayer.currentItem?.duration.seconds ?? 0
    }
    
    var isPlaying: Bool {
        queuePlayer.timeControlStatus == .playing
    }
    
    // MARK: - Initialization
    
    init() {
        queuePlayer.volume = 0.7
        queuePlayer.automaticallyWaitsToMinimizeStalling = true
        queuePlayer.actionAtItemEnd = .advance
    }
    
    // MARK: - Queue Management
    
    func setQueue(primaryURL: URL, primaryId: String, upcomingURLs: [(id: String, url: URL)]) async {
        cleanupQueue()
        
        let primaryItem = AVPlayerItem(url: primaryURL)
        registerItem(primaryItem, songId: primaryId)
        queuePlayer.insert(primaryItem, after: nil)
        
        currentSongId = primaryId
        
        setupObservers()
        setupCurrentItemObserver()
        
        let upcomingCount = min(upcomingURLs.count, 2)
        for i in 0..<upcomingCount {
            let (songId, url) = upcomingURLs[i]
            let item = AVPlayerItem(url: url)
            registerItem(item, songId: songId)
            queuePlayer.insert(item, after: queuePlayer.items().last)
        }
        
        queuePlayer.play()
        delegate?.playbackEngine(self, didChangePlayingState: true)
        
        AppLogger.general.info("PlaybackEngine: Queue set with \(upcomingCount + 1) items, starting: \(primaryId)")
    }
    
    func advanceToNextItem() {
        guard queuePlayer.items().count > 1 else {
            AppLogger.general.info("PlaybackEngine: No next item in queue")
            delegate?.playbackEngine(self, didFinishPlaying: true)
            return
        }
        
        queuePlayer.advanceToNextItem()
        AppLogger.general.info("PlaybackEngine: Advanced to next item")
    }
    
    func replaceQueue(with urls: [(id: String, url: URL)]) async {
        cleanupQueue()
        
        guard !urls.isEmpty else {
            AppLogger.general.info("PlaybackEngine: Cannot replace with empty queue")
            return
        }
        
        let itemsToLoad = min(urls.count, 3)
        for i in 0..<itemsToLoad {
            let (songId, url) = urls[i]
            let item = AVPlayerItem(url: url)
            registerItem(item, songId: songId)
            queuePlayer.insert(item, after: queuePlayer.items().last)
        }
        
        if let firstId = urls.first?.id {
            currentSongId = firstId
        }
        
        setupObservers()
        setupCurrentItemObserver()
        
        queuePlayer.play()
        delegate?.playbackEngine(self, didChangePlayingState: true)
        
        AppLogger.general.info("PlaybackEngine: Queue replaced with \(itemsToLoad) items")
    }
    
    func addItemsToQueue(_ urls: [(id: String, url: URL)]) async {
        guard !urls.isEmpty else { return }
        
        for (songId, url) in urls {
            let item = AVPlayerItem(url: url)
            registerItem(item, songId: songId)
            queuePlayer.insert(item, after: queuePlayer.items().last)
        }
        
        AppLogger.general.info("PlaybackEngine: Added \(urls.count) items to queue, total: \(currentQueueSize)")
    }

    // MARK: - Playback Control
    
    func pause() {
        queuePlayer.pause()
        delegate?.playbackEngine(self, didChangePlayingState: false)
        AppLogger.general.info("PlaybackEngine: Paused")
    }
    
    func resume() {
        queuePlayer.play()
        delegate?.playbackEngine(self, didChangePlayingState: true)
        AppLogger.general.info("PlaybackEngine: Resumed")
    }
    
    func stop() {
        cleanupQueue()
        delegate?.playbackEngine(self, didChangePlayingState: false)
        AppLogger.general.info("PlaybackEngine: Stopped")
    }
    
    func seek(to time: TimeInterval) {
        guard let currentItem = queuePlayer.currentItem else { return }
        
        let duration = currentItem.duration.seconds
        // duration can be NaN or infinite for HTTP streams before the item is ready;
        // CMTime(seconds: NaN) produces an invalid seek target.
        guard duration.isFinite else { return }
        let clampedTime = max(0, min(time, duration))
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        queuePlayer.seek(to: cmTime) { [weak self] finished in
            if finished, let self = self {
                Task { @MainActor in
                    self.delegate?.playbackEngine(self, didUpdateTime: clampedTime)
                }
            }
        }
    }
    
    // MARK: - Item Management
    
    private func registerItem(_ item: AVPlayerItem, songId: String) {
        let itemId = ObjectIdentifier(item)
        itemToSongId[itemId] = songId
        songIdToItem[songId] = item
        
        setupItemObserver(for: item)
        setupStatusObserver(for: item)
    }
    
    private func unregisterItem(_ item: AVPlayerItem) {
        let itemId = ObjectIdentifier(item)

        // FIXED Bug 16: cancel and remove this item's status task immediately.
        // In the old array-based approach this task would linger until the next
        // cleanupQueue() call. With many track advances the array could hold
        // dozens of tasks, each keeping a KVO observation on a dead item alive.
        statusObservers[itemId]?.cancel()
        statusObservers.removeValue(forKey: itemId)

        if let songId = itemToSongId[itemId] {
            itemToSongId.removeValue(forKey: itemId)
            songIdToItem.removeValue(forKey: songId)
        }
    }
    
    private func pruneOldItems() {
        let currentItems = queuePlayer.items()
        let maxItems = 5
        
        if songIdToItem.count > maxItems {
            let currentItemIds = Set(currentItems.map { ObjectIdentifier($0) })
            
            let itemsToRemove = itemToSongId.filter { !currentItemIds.contains($0.key) }
            for (itemId, songId) in itemsToRemove {
                // Cancel the status task for each pruned item.
                statusObservers[itemId]?.cancel()
                statusObservers.removeValue(forKey: itemId)

                itemToSongId.removeValue(forKey: itemId)
                songIdToItem.removeValue(forKey: songId)
            }
            
            AppLogger.general.info("PlaybackEngine: Pruned \(itemsToRemove.count) old items from tracking")
        }
    }
    
    // MARK: - Observer Setup
    
    private func setupObservers() {
        setupTimeObserver()
    }
    
    private func setupTimeObserver() {
        timeObserver = queuePlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                self.delegate?.playbackEngine(self, didUpdateTime: time.seconds)
            }
        }
    }
    
    private func setupCurrentItemObserver() {
        currentItemObserver = queuePlayer.observe(\.currentItem, options: [.new]) { [weak self] player, change in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let newItem = change.newValue as? AVPlayerItem {
                    let itemId = ObjectIdentifier(newItem)
                    if let songId = self.itemToSongId[itemId] {
                        self.currentSongId = songId
                        AppLogger.general.info("PlaybackEngine: Current item changed to: \(songId)")
                        self.delegate?.playbackEngine(self, didAdvanceToSongId: songId)
                        await self.checkAndExtendQueue()
                    }
                }
                self.pruneOldItems()
            }
        }
    }

    private func setupItemObserver(for item: AVPlayerItem) {
        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let finishedItem = notification.object as? AVPlayerItem else { return }
            
            Task { @MainActor in
                let itemId = ObjectIdentifier(finishedItem)
                if let songId = self.itemToSongId[itemId] {
                    AppLogger.general.info("PlaybackEngine: Item finished playing: \(songId)")
                }

                // Check BEFORE unregistering: if this is the only item left,
                // the queue is exhausted. Checking after unregister would always
                // see count == 0 and could race with AVQueuePlayer's own advance.
                let isLastItem = self.queuePlayer.items().count == 1
                self.unregisterItem(finishedItem)

                if isLastItem {
                    AppLogger.general.info("PlaybackEngine: Queue finished - no more items")
                    self.delegate?.playbackEngine(self, didFinishPlaying: true)
                } else {
                    AppLogger.general.info("PlaybackEngine: Continuing playback - \(self.queuePlayer.items().count) items remaining")
                }
            }
        }
        
        itemObservers.append(observer)
    }
    
    private func checkAndExtendQueue() async {
        guard !isExtendingQueue else { return }
        
        let queueSize = currentQueueSize
        
        guard queueSize < queueTargetSize else { return }
        
        isExtendingQueue = true
        defer { isExtendingQueue = false }
        
        AppLogger.general.info("PlaybackEngine: Queue low (\(queueSize) items), requesting more")
        await delegate?.playbackEngineNeedsMoreItems(self)
    }
    
    private func setupStatusObserver(for item: AVPlayerItem) {
        let itemId = ObjectIdentifier(item)

        // FIXED Bug 16: guard against double-registration for the same item.
        // If registerItem is somehow called twice for the same AVPlayerItem,
        // cancel the previous task before creating a new one.
        statusObservers[itemId]?.cancel()

        let task = Task { [weak self] in
            guard let self = self else { return }
            for await status in item.observeStatus() {
                await self.handlePlayerStatus(status, for: item)
            }
        }

        // Store keyed by item identity — O(1) lookup in unregisterItem.
        statusObservers[itemId] = task
    }
    
    private func handlePlayerStatus(_ status: AVPlayerItem.Status, for item: AVPlayerItem) async {
        switch status {
        case .readyToPlay:
            let duration = item.duration.seconds
            if !duration.isNaN && duration.isFinite {
                let itemId = ObjectIdentifier(item)
                if let songId = itemToSongId[itemId], songId == currentSongId {
                    delegate?.playbackEngine(self, didUpdateDuration: duration)
                    AppLogger.general.info("PlaybackEngine: Ready to play, duration: \(duration)s")
                }
            }
            
        case .failed:
            if let error = item.error {
                let itemId = ObjectIdentifier(item)
                if let songId = itemToSongId[itemId] {
                    AppLogger.general.info("PlaybackEngine: Item failed: \(songId) - \(error.localizedDescription)")
                }
                
                unregisterItem(item)
                
                delegate?.playbackEngine(self, didEncounterError: "Playback failed")
                
                if queuePlayer.items().count > 1 {
                    advanceToNextItem()
                } else {
                    delegate?.playbackEngine(self, didFinishPlaying: false)
                }
            }
            
        case .unknown:
            break
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanupQueue() {
        if let observer = timeObserver {
            queuePlayer.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        currentItemObserver?.invalidate()
        currentItemObserver = nil
        
        itemObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        itemObservers.removeAll()
        
        // FIXED Bug 16: cancel all tasks in the dictionary and clear it.
        statusObservers.values.forEach { $0.cancel() }
        statusObservers.removeAll()
        
        queuePlayer.pause()
        queuePlayer.removeAllItems()
        
        itemToSongId.removeAll()
        songIdToItem.removeAll()
        currentSongId = nil
    }

    deinit {
        // Task.cancel() and NotificationCenter.removeObserver() are safe from deinit.
        statusObservers.values.forEach { $0.cancel() }
        itemObservers.forEach { NotificationCenter.default.removeObserver($0) }
        AppLogger.general.warn("PlaybackEngine: Deinitialized - call shutdown() before release")
    }
    
    /// MUST be called before releasing the engine
    func shutdown() {
        cleanupQueue()
    }
}

// MARK: - AVPlayerItem Extension

extension AVPlayerItem {
    func observeStatus() -> AsyncStream<Status> {
        AsyncStream { continuation in
            let observation = observe(\.status, options: [.new]) { item, change in
                if let newStatus = change.newValue {
                    continuation.yield(newStatus)
                }
            }
            
            continuation.onTermination = { _ in
                observation.invalidate()
            }
        }
    }
}
