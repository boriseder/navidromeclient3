//
//  QueueView.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Generic Inference errors
//

import SwiftUI

struct QueueView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(playerVM.queue) { song in
                    HStack(spacing: 12) {
                        // Playing Indicator
                        if playerVM.currentSong?.id == song.id {
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(.caption)
                        } else {
                            Text("\(playerVM.queue.firstIndex(where: { $0.id == song.id }) ?? 0 + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20, alignment: .center)
                                .monospacedDigit()
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.body)
                                .lineLimit(1)
                                .foregroundStyle(playerVM.currentSong?.id == song.id ? Color.accentColor : .primary)
                            
                            Text(song.artist ?? "Unknown Artist")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if let duration = song.duration {
                            Text(formatDuration(duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let index = playerVM.queue.firstIndex(where: { $0.id == song.id }) {
                            playerVM.playQueue(songs: playerVM.queue, startIndex: index)
                        }
                    }
                }
                .onMove { source, destination in
                    playerVM.moveQueueItem(from: source, to: destination)
                }
                .onDelete { offsets in
                    playerVM.removeQueueItem(at: offsets)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Up Next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton() // Enables drag-and-drop reordering
                }
            }
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
