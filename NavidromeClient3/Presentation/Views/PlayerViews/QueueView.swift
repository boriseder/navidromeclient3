//
//  QueueView.swift
//  NavidromeClient3
//
//  Swift 6: Queue Management UI
//

import SwiftUI

struct QueueView: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if let current = player.currentSong {
                    Section("Now Playing") {
                        QueueRow(song: current, isPlaying: true)
                    }
                }
                
                Section("Up Next") {
                    ForEach(player.queue.indices, id: \.self) { index in
                        // Only show songs after the current index
                        if index > player.currentIndex {
                            QueueRow(song: player.queue[index], isPlaying: false)
                                .onTapGesture {
                                    // Jump to track
                                    player.currentIndex = index
                                    Task { await player.play(song: player.queue[index], context: player.queue) } // Re-trigger load
                                }
                        }
                    }
                    .onMove { source, destination in
                        player.moveQueueItem(from: source, to: destination)
                    }
                    .onDelete { indexSet in
                        player.removeQueueItem(at: indexSet)
                    }
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
    }
}

struct QueueRow: View {
    let song: Song
    let isPlaying: Bool
    
    var body: some View {
        HStack {
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.footnote)
            }
            
            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(isPlaying ? Color.accentColor : .primary)
                
                Text(song.artist ?? "Unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
