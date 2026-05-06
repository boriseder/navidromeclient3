import Foundation
import SwiftUI
import AVFoundation

@MainActor
@Observable
class PlaylistManager {
    private(set) var currentPlaylist: [Song] = []
    private(set) var currentIndex: Int = 0
    private(set) var isShuffling: Bool = false

    var repeatMode: RepeatMode = .off

    enum RepeatMode { case off, all, one }

    var currentSong: Song? { currentPlaylist.indices.contains(currentIndex) ? currentPlaylist[currentIndex] : nil }

    func setPlaylist(_ songs: [Song], startIndex: Int = 0) {
        currentPlaylist = songs
        currentIndex = max(0, min(startIndex, songs.count - 1))
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
        }
    }
    
    func moveToPrevious(currentTime: TimeInterval) {
        currentIndex = previousIndex(currentTime: currentTime)
    }
    
    func toggleShuffle() {
        isShuffling.toggle()
        
        if isShuffling {
            guard let currentSong = currentSong else { return }
            
            // Remove current song
            var songsToShuffle = currentPlaylist
            songsToShuffle.remove(at: currentIndex)
            
            // Shuffle remaining songs
            songsToShuffle.shuffle()
            
            // Put current song at front
            currentPlaylist = [currentSong] + songsToShuffle
            currentIndex = 0
            
            AppLogger.general.info("🔀 Shuffle enabled - \(currentPlaylist.count) songs")
        }
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
}

extension PlaylistManager {
    
    // MARK: - Queue Navigation
    
    func jumpToSong(at index: Int) {
        guard currentPlaylist.indices.contains(index) else {
            AppLogger.general.warn("Invalid queue index: \(index)")
            return
        }
        currentIndex = index
        AppLogger.general.info("Jumped to queue position \(index): \(currentPlaylist[index].title)")
    }
    
    // MARK: - Queue Modification
    
    func removeSong(at index: Int) {
        guard currentPlaylist.indices.contains(index) else {
            AppLogger.general.info("⚠️ Cannot remove song at invalid index: \(index)")
            return
        }
        
        let removedSong = currentPlaylist.remove(at: index)
        AppLogger.general.info("🗑️ Removed from queue: \(removedSong.title)")
        
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            if currentIndex >= currentPlaylist.count {
                currentIndex = max(0, currentPlaylist.count - 1)
            }
        }
    }
    
    func removeSongs(at indices: [Int]) {
        let sortedIndices = indices.sorted(by: >)
        
        for index in sortedIndices {
            guard currentPlaylist.indices.contains(index) else { continue }
            removeSong(at: index)
        }
    }
    
    func moveSong(from source: Int, to destination: Int) {
        guard currentPlaylist.indices.contains(source),
              destination >= 0 && destination <= currentPlaylist.count else {
            AppLogger.general.info("⚠️ Invalid move operation: \(source) -> \(destination)")
            return
        }
        
        let song = currentPlaylist.remove(at: source)
        let adjustedDestination = source < destination ? destination - 1 : destination
        currentPlaylist.insert(song, at: adjustedDestination)
        
        if source == currentIndex {
            currentIndex = adjustedDestination
        } else if source < currentIndex && adjustedDestination >= currentIndex {
            currentIndex -= 1
        } else if source > currentIndex && adjustedDestination <= currentIndex {
            currentIndex += 1
        }
        
        AppLogger.general.info("🔄 Moved queue item: \(song.title) from \(source) to \(adjustedDestination)")
    }
    
    func moveSongs(from sourceIndices: [Int], to destinationIndex: Int) {
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
    
    func shuffleUpNext() {
        guard currentPlaylist.count > currentIndex + 1 else {
            AppLogger.general.warn("No upcoming songs to shuffle")
            return
        }
        
        let upcomingSongs = Array(currentPlaylist[(currentIndex + 1)...])
        let shuffledUpcoming = upcomingSongs.shuffled()
        
        currentPlaylist = Array(currentPlaylist[0...currentIndex]) + shuffledUpcoming
        
        AppLogger.general.info("Shuffled \(shuffledUpcoming.count) upcoming songs")
    }
    
    func clearUpNext() {
        guard currentPlaylist.count > currentIndex + 1 else {
            AppLogger.general.warn("No upcoming songs to clear")
            return
        }
        
        let removedCount = currentPlaylist.count - currentIndex - 1
        currentPlaylist = Array(currentPlaylist[0...currentIndex])
        
        AppLogger.general.info("Cleared \(removedCount) upcoming songs from queue")
    }
    
    func addToQueue(_ songs: [Song]) {
        guard !songs.isEmpty else { return }
        
        currentPlaylist.append(contentsOf: songs)
        
        AppLogger.general.info("Added \(songs.count) songs to queue")
    }
    
    func playNext(_ songs: [Song]) {
        guard !songs.isEmpty else { return }
        
        let insertIndex = currentIndex + 1
        for (offset, song) in songs.enumerated() {
            currentPlaylist.insert(song, at: insertIndex + offset)
        }
        AppLogger.general.info("Inserted \(songs.count) songs to play next")
    }
    
    // MARK: - Queue Information
    
    func getUpNextSongs() -> [Song] {
        guard currentIndex + 1 < currentPlaylist.count else { return [] }
        return Array(currentPlaylist[(currentIndex + 1)...])
    }
    
    func getTotalDuration() -> Int {
        return currentPlaylist.reduce(0) { total, song in
            total + (song.duration ?? 0)
        }
    }
    
    func getRemainingDuration() -> Int {
        return getUpNextSongs().reduce(0) { total, song in
            total + (song.duration ?? 0)
        }
    }
    
    func hasUpNext() -> Bool {
        return currentIndex + 1 < currentPlaylist.count
    }
    
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
