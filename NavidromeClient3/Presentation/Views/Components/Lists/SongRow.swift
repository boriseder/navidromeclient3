//
//  SongRow.swift
//  NavidromeClient3
//
//  Swift 6: Explicit Init to fix "Missing Arguments" error
//

import SwiftUI

struct SongRow: View {
    let song: Song
    let trackNumber: Int?
    let isPlaying: Bool
    
    // FIX: Added explicit init to guarantee parameter matching
    init(song: Song, trackNumber: Int? = nil, isPlaying: Bool = false) {
        self.song = song
        self.trackNumber = trackNumber
        self.isPlaying = isPlaying
    }
    
    var body: some View {
        HStack(spacing: 8) { // Replaced DSLayout.elementGap with literal or use DesignSystem if available
            if isPlaying {
                EqualizerBars()
                    .frame(width: 20, height: 20)
            } else if let track = trackNumber {
                Text("\(track)")
                    .font(.caption) // DSText.metadata
                    .foregroundStyle(.secondary) // DSColor.secondary
                    .frame(width: 20, alignment: .center)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body) // DSText.body
                    .foregroundStyle(isPlaying ? Color.accentColor : .primary)
                    .lineLimit(1)
                
                if let artist = song.artist {
                    Text(artist)
                        .font(.caption) // DSText.metadata
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let duration = song.duration {
                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16) // DSLayout.contentPadding
        .contentShape(Rectangle())
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
