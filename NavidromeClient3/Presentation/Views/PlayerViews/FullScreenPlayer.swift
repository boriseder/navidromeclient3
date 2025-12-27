//
//  FullScreenPlayer.swift
//  NavidromeClient3
//
//  Swift 6: High Performance Player UI
//

import SwiftUI

struct FullScreenPlayer: View {
    // 1. Inject Player
    @Environment(PlayerViewModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        // 2. Bindable for sliders
        @Bindable var bPlayer = player
        
        GeometryReader { geometry in
            VStack(spacing: 24) {
                // Dismiss Indicator
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 40, height: 4)
                    .padding(.top, 10)
                
                // Cover Art
                if let song = player.currentSong {
                    AlbumImageView(
                        albumId: song.albumId ?? "",
                        size: 600
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 10)
                    .padding(.horizontal, 40)
                    .frame(height: geometry.size.width - 80)
                }
                
                // Metadata
                VStack(spacing: 4) {
                    Text(player.currentSong?.title ?? "Not Playing")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    
                    Text(player.currentSong?.artist ?? "Unknown Artist")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                
                // Scrubber
                VStack(spacing: 8) {
                    // Binding to duration property
                    Slider(value: $bPlayer.currentTime, in: 0...(player.duration)) { editing in
                        if editing { player.isScrubbing = true }
                        else { player.seek(to: player.currentTime) }
                    }
                    .tint(Color.accentColor)
                    
                    HStack {
                        Text(formatTime(player.currentTime))
                        Spacer()
                        Text(formatTime(player.duration))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
                .padding(.horizontal)
                
                // Controls
                HStack(spacing: 40) {
                    Button {
                        player.previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 30))
                    }
                    
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                    }
                    
                    Button {
                        player.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 30))
                    }
                }
                .foregroundStyle(.primary)
                .padding(.bottom, 40)
            }
        }
        .background(DynamicMusicBackground(image: nil)) // Ideally pass image here
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
