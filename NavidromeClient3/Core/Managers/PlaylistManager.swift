import Foundation
import SwiftUI
import AVFoundation

@MainActor
class PlaylistManager: ObservableObject {
    @Published private(set) var currentPlaylist: [Song] = []
    @Published private(set) var currentIndex: Int = 0
    @Published var isShuffling: Bool = false
    @Published var repeatMode: RepeatMode = .off

    enum RepeatMode { case off, all, one }

    var currentSong: Song? { currentPlaylist.indices.contains(currentIndex) ? currentPlaylist[currentIndex] : nil }

    func setPlaylist(_ songs: [Song], startIndex: Int = 0) {
        currentPlaylist = songs
        currentIndex = max(0, min(startIndex, songs.count - 1))
        objectWillChange.send()
    }

    func nextIndex() -> Int? {
        switch repeatMode {
        case .one: return currentIndex
        case .off: let next = currentIndex + 1; return next < currentPlaylist.count ? next : nil
        case .all: return (currentIndex + 1) % currentPlaylist.count
        }
    }

    func previousIndex(currentTime: TimeInterval) -> Int {
        if currentTime > 5 { return currentIndex }
        else { return currentIndex > 0 ? currentIndex - 1 : (repeatMode == .all ? currentPlaylist.count - 1 : 0) }
    }

    func advanceToNext() {
        if let next = nextIndex() {
            currentIndex = next
            objectWillChange.send()
        }
    }
    
    func moveToPrevious(currentTime: TimeInterval) {
        currentIndex = previousIndex(currentTime: currentTime)
        objectWillChange.send()
    }
    
    func toggleShuffle() {
        isShuffling.toggle();
        if isShuffling {
            currentPlaylist.shuffle()
            objectWillChange.send()
        }
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
        objectWillChange.send()
    }
}

extension PlaylistManager {
    
    // MARK: - Queue Navigation
    
    /// Jump to a specific song in the queue
    func jumpToSong(at index: Int) {
        guard currentPlaylist.indices.contains(index) else {
            AppLogger.general.warn("Invalid queue index: \(index)")
            return
        }
        currentIndex = index
        objectWillChange.send()
        AppLogger.general.info("Jumped to queue position \(index): \(currentPlaylist[index].title)")
    }
    
    // MARK: - Queue Modification
    
    /// Remove a song from the queue
    func removeSong(at index: Int) {
        guard currentPlaylist.indices.contains(index) else {
            AppLogger.general.info("⚠️ Cannot remove song at invalid index: \(index)")
            return
        }
        
        let removedSong = currentPlaylist.remove(at: index)
        AppLogger.general.info("🗑️ Removed from queue: \(removedSong.title)")
        
        // Adjust current index
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            // If we removed the current song, stay at same index but play new song there
            if currentIndex >= currentPlaylist.count {
                currentIndex = max(0, currentPlaylist.count - 1)
            }
        }
        objectWillChange.send()
    }
    
    /// Remove multiple songs from the queue
    func removeSongs(at indices: [Int]) {
        let sortedIndices = indices.sorted(by: >) // Remove from back to front
        
        for index in sortedIndices {
            guard currentPlaylist.indices.contains(index) else { continue }
            removeSong(at: index)
        }
    }
    
    /// Move a song within the queue
    func moveSong(from source: Int, to destination: Int) {
        guard currentPlaylist.indices.contains(source),
              destination >= 0 && destination <= currentPlaylist.count else {
            AppLogger.general.info("⚠️ Invalid move operation: \(source) -> \(destination)")
            return
        }
        
        let song = currentPlaylist.remove(at: source)
        let adjustedDestination = source < destination ? destination - 1 : destination
        currentPlaylist.insert(song, at: adjustedDestination)
        
        // Adjust currentIndex accordingly
        if source == currentIndex {
            currentIndex = adjustedDestination
        } else if source < currentIndex && adjustedDestination >= currentIndex {
            currentIndex -= 1
        } else if source > currentIndex && adjustedDestination <= currentIndex {
            currentIndex += 1
        }
        
        objectWillChange.send()
        AppLogger.general.info("🔄 Moved queue item: \(song.title) from \(source) to \(adjustedDestination)")
    }
    
    /// Move multiple songs within the queue
    func moveSongs(from sourceIndices: [Int], to destinationIndex: Int) {
        // Simple implementation: move one by one
        let sortedSources = sourceIndices.sorted()
        var adjustedDestination = destinationIndex
        
        for (offset, sourceIndex) in sortedSources.enumerated() {
            let currentSource = sourceIndex - offset
            moveSong(from: currentSource, to: adjustedDestination)
            
            if currentSource < adjustedDestination {
                adjustedDestination -= 1
            }
        }
    }
    
    // MARK: - Queue Shuffling
    
    /// Shuffle only the upcoming songs (not the current song)
    func shuffleUpNext() {
        guard currentPlaylist.count > currentIndex + 1 else {
            AppLogger.general.warn("No upcoming songs to shuffle")
            return
        }
        
        //let currentSong = currentPlaylist[currentIndex]
        let upcomingSongs = Array(currentPlaylist[(currentIndex + 1)...])
        let shuffledUpcoming = upcomingSongs.shuffled()
        
        // Rebuild playlist: current song + shuffled upcoming
        currentPlaylist = Array(currentPlaylist[0...currentIndex]) + shuffledUpcoming
        
        objectWillChange.send()
        AppLogger.general.info("Shuffled \(shuffledUpcoming.count) upcoming songs")
    }
    
    /// Clear all songs after the current song
    func clearUpNext() {
        guard currentPlaylist.count > currentIndex + 1 else {
            AppLogger.general.warn("No upcoming songs to clear")
            return
        }
        
        let removedCount = currentPlaylist.count - currentIndex - 1
        currentPlaylist = Array(currentPlaylist[0...currentIndex])
        
        objectWillChange.send()
        AppLogger.general.info("Cleared \(removedCount) upcoming songs from queue")
    }
    
    /// Add songs to the end of the queue
    func addToQueue(_ songs: [Song]) {
        guard !songs.isEmpty else { return }
        
        currentPlaylist.append(contentsOf: songs)
        
        objectWillChange.send()
        AppLogger.general.info("Added \(songs.count) songs to queue")
    }
    
    /// Insert songs after the current song
    func playNext(_ songs: [Song]) {
        guard !songs.isEmpty else { return }
        
        let insertIndex = currentIndex + 1
        for (offset, song) in songs.enumerated() {
            currentPlaylist.insert(song, at: insertIndex + offset)
        }
        objectWillChange.send()
        AppLogger.general.info("Inserted \(songs.count) songs to play next")
    }
    
    // MARK: - Queue Information
    
    /// Get upcoming songs in the queue
    func getUpNextSongs() -> [Song] {
        guard currentIndex + 1 < currentPlaylist.count else { return [] }
        return Array(currentPlaylist[(currentIndex + 1)...])
    }
    
    /// Get total queue duration
    func getTotalDuration() -> Int {
        return currentPlaylist.reduce(0) { total, song in
            total + (song.duration ?? 0)
        }
    }
    
    /// Get remaining queue duration
    func getRemainingDuration() -> Int {
        return getUpNextSongs().reduce(0) { total, song in
            total + (song.duration ?? 0)
        }
    }
    
    /// Check if there are songs after the current one
    func hasUpNext() -> Bool {
        return currentIndex + 1 < currentPlaylist.count
    }
    
    /// Get upcoming songs for preloading (respects repeat mode)
    func getUpcoming(count: Int) -> [Song] {
        guard !currentPlaylist.isEmpty else { return [] }
        
        var upcoming: [Song] = []
        var index = currentIndex + 1
        
        for _ in 0..<count {
            if index >= currentPlaylist.count {
                switch repeatMode {
                case .off:
                    break
                case .all:
                    index = 0
                case .one:
                    if let currentSong = currentSong {
                        upcoming.append(currentSong)
                    }
                    continue
                }
            }
            
            if index < currentPlaylist.count {
                upcoming.append(currentPlaylist[index])
                index += 1
            }
        }
        
        return upcoming
    }
}
