//
//  SongRow.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Compliance
//

import SwiftUI

struct SongRow: View {
    let song: Song
    var context: SongRowContext = .album
    var showCover: Bool = false
    
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(CoverArtManager.self) var coverArtManager
    
    enum SongRowContext {
        case album
        case playlist
        case search
        case favorites
    }
    
    private var isPlaying: Bool {
        return playerVM.currentSong?.id == song.id
    }
    
    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
            if isPlaying {
                EqualizerBars(isActive: playerVM.isPlaying, accentColor: DSColor.primary)
                    .frame(width: 20)
            } else if showCover {
                AlbumImageView(
                    album: Album(
                        id: song.albumId ?? "",
                        parent: nil,
                        album: song.album ?? "",
                        title: song.album ?? "",
                        name: song.album ?? "",
                        isDir: false,
                        coverArt: song.coverArt,
                        artist: song.artist ?? "",
                        artistId: nil,
                        created: nil,
                        duration: 0,
                        playCount: 0,
                        songCount: 0,
                        year: nil,
                        genre: nil,
                        song: nil
                    ),
                    context: .list
                )
                .frame(width: 40, height: 40)
            } else if let track = song.track {
                Text("\(track)")
                    .font(DSText.metadata.monospacedDigit())
                    .foregroundStyle(DSColor.secondary)
                    .frame(width: 20, alignment: .center)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(DSText.body)
                    .foregroundStyle(isPlaying ? DSColor.primary : DSColor.onLight)
                    .lineLimit(1)
                
                if context != .album {
                    Text(song.artist ?? "Unknown Artist")
                        .font(DSText.metadata)
                        .foregroundStyle(DSColor.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let duration = song.duration {
                Text(formatDuration(duration))
                    .font(DSText.metadata)
                    .foregroundStyle(DSColor.secondary)
            }
            
            Menu {
                Button {
                    // Fixed: No await needed for synchronous method
                    playerVM.playNext([song])
                } label: {
                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                
                Button {
                    playerVM.addToQueue([song])
                } label: {
                    Label("Add to Queue", systemImage: "text.append")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundStyle(DSColor.secondary)
                    .padding(8)
                    .contentShape(Rectangle())
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
