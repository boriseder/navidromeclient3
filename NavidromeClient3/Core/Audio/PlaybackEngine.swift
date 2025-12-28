//
//  PlaybackEngine.swift
//  NavidromeClient3
//
//  Swift 6: Cleaned - Removed unnecessary Combine import
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
}

@MainActor
final class PlaybackEngine: NSObject {
    static let shared = PlaybackEngine()
    
    // MARK: - Properties
    private var player: AVPlayer
    private var timeObserver: Any?
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
    
    // MARK: - Public API
    
    func play(url: URL, songId: String) {
        setQueue(primaryURL: url, primaryId: songId, upcomingURLs: [])
    }
    
    func setQueue(primaryURL: URL, primaryId: String, upcomingURLs: [(String, URL)]) {
        // Reset previous observers
        itemObservers.forEach { NotificationCenter.default.removeObserver($0) }
        itemObservers.removeAll()
        itemToSongId.removeAll()
        
        let item = AVPlayerItem(url: primaryURL)
        self.currentSongId = primaryId
        self.itemToSongId[item] = primaryId
        
        // Notification Observer (Foundation)
        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            guard let object = notification.object as? AVPlayerItem else { return }
            Task { @MainActor in
                self?.handleItemDidFinishPlaying(item: object)
            }
        }
        itemObservers.append(observer)
        
        // KVO Observer (Foundation)
        let statusObserver = item.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                self?.handleItemStatusChange(item)
            }
        }
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
}
