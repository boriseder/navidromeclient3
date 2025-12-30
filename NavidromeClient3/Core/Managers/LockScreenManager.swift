//
//  LockScreenManager.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Concurrency Crashes (MPNowPlayingInfoCenter)
//

import Foundation
import MediaPlayer
import Observation
import UIKit

@MainActor
final class LockScreenManager {
    static let shared = LockScreenManager()
    
    weak var playerVM: PlayerViewModel?
    
    private init() {
        setupRemoteCommands()
    }
    
    func configure(playerVM: PlayerViewModel) {
        self.playerVM = playerVM
    }
    
    // MARK: - Now Playing Info
    
    func updateNowPlaying(song: Song?, image: UIImage?, duration: Double, currentTime: Double, isPlaying: Bool) {
        guard let song = song else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.album
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // FIX: Use nonisolated helper to create artwork.
        // This prevents the closure from capturing MainActor isolation, which causes crashes
        // when MPNowPlayingInfoCenter runs it on a background queue.
        if let image = image {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = createArtwork(from: image)
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Helper (Non-Isolated)
    
    // This function runs outside the MainActor, so its closure `{ _ in image }`
    // does not enforce Main Thread execution.
    nonisolated private func createArtwork(from image: UIImage) -> MPMediaItemArtwork {
        return MPMediaItemArtwork(boundsSize: image.size) { _ in
            return image
        }
    }
    
    // MARK: - Remote Commands
    
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        
        // FIX: Wrap calls in Task { @MainActor } because these blocks run on a background thread.
        // We return .success immediately (optimistic UI) and perform the action async.
        
        // Play/Pause
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playerVM?.resume() }
            return .success
        }
        
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playerVM?.pause() }
            return .success
        }
        
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playerVM?.togglePlayPause() }
            return .success
        }
        
        // Navigation
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playerVM?.nextTrack() }
            return .success
        }
        
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playerVM?.previousTrack() }
            return .success
        }
        
        // Seeking
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.playerVM?.seek(to: event.positionTime) }
            return .success
        }
        
        // Scrubber / Skip
        center.seekForwardCommand.isEnabled = false
        center.seekBackwardCommand.isEnabled = false
    }
}
