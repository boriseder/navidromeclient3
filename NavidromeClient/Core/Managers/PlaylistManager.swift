//
//  PlaylistManager.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Observable
//

import Foundation
import Observation

@MainActor
@Observable
class PlaylistManager {
    
    // MARK: - State
    
    private(set) var currentPlaylist: [Song] = []
    private(set) var currentIndex: Int = 0
    var isShuffling: Bool = false
    var repeatMode: RepeatMode = .off
    
    // MARK: - Types
    
    enum RepeatMode: Sendable {
        case off, all, one
    }
    
    // MARK: - Derived Properties
    
    var currentSong: Song? {
        guard currentPlaylist.indices.contains(currentIndex) else { return nil }
        return currentPlaylist[currentIndex]
    }
    
    var hasNext: Bool {
        return !currentPlaylist.isEmpty && (repeatMode != .off || currentIndex < currentPlaylist.count - 1)
    }
    
    var hasPrevious: Bool {
        return !currentPlaylist.isEmpty && (repeatMode != .off || currentIndex > 0)
    }
    
    // MARK: - Actions
    
    func setPlaylist(_ songs: [Song], startIndex: Int = 0) {
        self.currentPlaylist = songs
        self.currentIndex = max(0, min(startIndex, songs.count - 1))
    }
    
    func advanceToNext() {
        guard !currentPlaylist.isEmpty else { return }
        
        if repeatMode == .one {
            // Do nothing, index stays same
        } else if currentIndex < currentPlaylist.count - 1 {
            currentIndex += 1
        } else if repeatMode == .all {
            currentIndex = 0
        }
    }
    
    func moveToPrevious(currentTime: TimeInterval) {
        // If > 3 seconds in, restart song
        if currentTime > 3.0 {
            return
        }
        
        if currentIndex > 0 {
            currentIndex -= 1
        } else if repeatMode == .all {
            currentIndex = currentPlaylist.count - 1
        }
    }
    
    func jumpToSong(at index: Int) {
        guard currentPlaylist.indices.contains(index) else { return }
        currentIndex = index
    }
    
    func toggleShuffle() {
        isShuffling.toggle()
        
        if isShuffling {
            // Shuffle rest of queue (excluding current song)
            guard currentPlaylist.count > 1 else { return }
            let current = currentPlaylist[currentIndex]
            
            var remaining = currentPlaylist
            remaining.remove(at: currentIndex)
            remaining.shuffle()
            
            self.currentPlaylist = [current] + remaining
            self.currentIndex = 0
        } else {
            // In a real app, you might want to restore original order
            // For now, we leave it as is but disable the flag
        }
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    // MARK: - Queue Management
    
    func addToQueue(_ songs: [Song]) {
        currentPlaylist.append(contentsOf: songs)
    }
    
    func playNext(_ songs: [Song]) {
        guard !currentPlaylist.isEmpty else {
            setPlaylist(songs)
            return
        }
        currentPlaylist.insert(contentsOf: songs, at: currentIndex + 1)
    }
    
    func removeSongs(at indices: [Int]) {
        let sortedIndices = indices.sorted(by: >)
        for index in sortedIndices {
            guard currentPlaylist.indices.contains(index) else { continue }
            currentPlaylist.remove(at: index)
            
            // Adjust current index if needed
            if index < currentIndex {
                currentIndex -= 1
            }
        }
        // Ensure index is valid
        if currentIndex >= currentPlaylist.count {
            currentIndex = max(0, currentPlaylist.count - 1)
        }
    }
    
    func moveSongs(from sourceIndices: [Int], to destinationIndex: Int) {
        // Simple implementation for single move (SwiftUI usually gives IndexSet)
        // For complex multi-selection moves, logic is more involved.
        // Assuming contiguous or simple moves for now.
    }
    
    func shuffleUpNext() {
        guard currentPlaylist.count > currentIndex + 1 else { return }
        
        let nextIndex = currentIndex + 1
        let upNext = currentPlaylist[nextIndex...]
        let shuffled = upNext.shuffled()
        
        currentPlaylist.replaceSubrange(nextIndex..., with: shuffled)
    }
    
    func clearUpNext() {
        guard currentPlaylist.count > currentIndex + 1 else { return }
        currentPlaylist.removeSubrange((currentIndex + 1)...)
    }
    
    // MARK: - Info
    
    func getUpNextSongs() -> [Song] {
        guard currentPlaylist.count > currentIndex + 1 else { return [] }
        return Array(currentPlaylist[(currentIndex + 1)...])
    }
    
    func getUpcoming(count: Int) -> [Song] {
        guard !currentPlaylist.isEmpty else { return [] }
        
        var songs: [Song] = []
        var idx = currentIndex + 1
        
        while songs.count < count {
            if idx >= currentPlaylist.count {
                if repeatMode == .all {
                    idx = 0
                } else {
                    break
                }
            }
            // Prevent infinite loop if playlist has 1 song and repeat all
            if idx == currentIndex && songs.count > 0 { break }
            
            songs.append(currentPlaylist[idx])
            idx += 1
        }
        
        return songs
    }
    
    func getTotalDuration() -> Int {
        currentPlaylist.reduce(0) { $0 + ($1.duration ?? 0) }
    }
    
    func getRemainingDuration() -> Int {
        getUpNextSongs().reduce(0) { $0 + ($1.duration ?? 0) }
    }
}
