//
//  PlaybackEngine.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Data Races & Observer Storage
//

@preconcurrency import AVFoundation
import Combine
import MediaPlayer

// MARK: - Delegate Protocol
@MainActor
protocol PlaybackEngineDelegate: AnyObject {
    func playbackEngine(_ engine: PlaybackEngine, didUpdateTime time: Double)
    func playbackEngine(_ engine: PlaybackEngine, didUpdateDuration duration: Double)
    func playbackEngine(_ engine: PlaybackEngine, didChangePlayingState isPlaying: Bool)
    func playbackEngine(_ engine: PlaybackEngine, didFinishPlaying successfully: Bool)
    func playbackEngine(_ engine: PlaybackEngine, didEncounterError error: String)
}

@MainActor
final class PlaybackEngine: NSObject {
    static let shared = PlaybackEngine()
    
    // MARK: - Properties
    private var player: AVPlayer
    private var timeObserver: Any?
    // FIX: itemObservers holds all observers (NotificationCenter tokens AND KVO observers)
    private var itemObservers: [NSObjectProtocol] = []
    
    // Track current item ID manually
    private var itemToSongId: [AVPlayerItem: String] = [:]
    private var currentSongId: String?
    
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
        self.player = AVPlayer()
        super.init()
        setupAudioSession()
        setupTimeObserver()
    }
    
    // FIX: Removed deinit.
    // Swift 6 prevents access to MainActor properties (player, itemObservers) from deinit.
    // Since this is a Singleton, it lives for the app's lifetime.
    // If you need to stop it manually, call this cleanup function.
    func cleanup() {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        itemObservers.forEach { NotificationCenter.default.removeObserver($0) }
        itemObservers.removeAll()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        // FIX: The closure is @Sendable (non-isolated).
        // We must hop back to MainActor to access 'delegate'.
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                self.delegate?.playbackEngine(self, didUpdateTime: time.seconds)
                
                // Also update duration if available and valid
                if let duration = self.player.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
                    self.delegate?.playbackEngine(self, didUpdateDuration: duration)
                }
            }
        }
    }
    
    // MARK: - Public API
    
    func play(url: URL, songId: String) {
        setQueue(primaryURL: url, primaryId: songId, upcomingURLs: [])
    }
    
    func setQueue(primaryURL: URL, primaryId: String, upcomingURLs: [(String, URL)]) {
        // Reset previous observers
        itemObservers.forEach { NotificationCenter.default.removeObserver($0) }
        itemObservers.removeAll()
        itemToSongId.removeAll() // Clear old mapping
        
        let item = AVPlayerItem(url: primaryURL)
        self.currentSongId = primaryId
        self.itemToSongId[item] = primaryId
        
        // FIX: Handle Notification Data Race
        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            // 1. Extract the Sendable item here (synchronously)
            guard let object = notification.object as? AVPlayerItem else { return }
            
            // 2. Pass the ITEM, not the NOTIFICATION, into the Task
            Task { @MainActor in
                self?.handleItemDidFinishPlaying(item: object)
            }
        }
        itemObservers.append(observer)
        
        // FIX: Handle "statusObserver was never used"
        let statusObserver = item.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                self?.handleItemStatusChange(item)
            }
        }
        // Store it so it isn't deallocated immediately
        itemObservers.append(statusObserver)
        
        player.replaceCurrentItem(with: item)
        player.play()
        
        delegate?.playbackEngine(self, didChangePlayingState: true)
    }
    
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
    
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
        player.seek(to: cmTime)
    }
    
    // MARK: - Private Handlers
    
    // FIX: Changed signature to take AVPlayerItem directly instead of Notification
    private func handleItemDidFinishPlaying(item: AVPlayerItem) {
        delegate?.playbackEngine(self, didFinishPlaying: true)
    }
    
    private func handleItemStatusChange(_ item: AVPlayerItem) {
        switch item.status {
        case .failed:
            if let error = item.error {
                delegate?.playbackEngine(self, didEncounterError: error.localizedDescription)
            }
        default:
            break
        }
    }
    
    private func setupNowPlaying(songId: String) {
        // Placeholder for MPNowPlayingInfoCenter logic
    }
}
