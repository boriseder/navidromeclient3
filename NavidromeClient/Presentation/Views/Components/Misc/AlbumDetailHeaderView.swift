//
//  AlbumDetailHeaderView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency & @Observable
//  - FIXED: Added 'import Observation'
//

import SwiftUI
import Observation

struct AlbumHeaderView: View {
    let album: Album
    let songs: [Song]
    let isOfflineAlbum: Bool

    @Environment(AppConfig.self) var appConfig
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(DownloadManager.self) var downloadManager

    var body: some View {
        VStack {
            albumHeroContent
        }
    }

    @ViewBuilder
    private var albumHeroContent: some View {
        VStack(alignment: .leading, spacing: DSLayout.sectionGap) {
            AlbumImageView(album: album, context: .detail)
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 10)
                .shadow(color: .black.opacity(0.3), radius: 40, x: 0, y: 20)

            VStack(alignment: .leading, spacing: DSLayout.contentGap) {
                Text(album.name)
                    .font(DSText.sectionTitle)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.9), radius: 1, x: 0, y: 1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(album.artist)
                    .font(DSText.prominent)
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(buildMetadataString())
                    .font(DSText.metadata)
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.7), radius: 1, x: 0, y: 1)
                    .multilineTextAlignment(.leading)
               
                actionButtonsFloating
                
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var actionButtonsFloating: some View {
        HStack(spacing: 12) {
            // PLAY BUTTON
            Button {
                Task {
                    if isAlbumCurrentlyLoaded {
                        playerVM.togglePlayPause()
                    } else {
                        await playAlbum()
                    }
                }
            } label: {
                HStack(spacing: DSLayout.contentGap) {
                    Image(systemName: playerVM.isPlaying && isAlbumCurrentlyLoaded ? "pause.fill" : "play.fill")
                        .font(DSText.emphasized)
                    Text(playerVM.isPlaying && isAlbumCurrentlyLoaded ? "Pause" : "Play")
                        .font(DSText.emphasized)
                }
                .foregroundStyle(playerVM.isPlaying && isAlbumCurrentlyLoaded ? .white : .green)
                .padding(.horizontal, DSLayout.contentPadding)
                .padding(.vertical, DSLayout.elementPadding)
                .background(
                    Capsule()
                        .fill(playerVM.isPlaying && isAlbumCurrentlyLoaded ? .green : .black)
                        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
                )
                .overlay(Capsule().stroke(.green, lineWidth: 1.5))
            }

            // SHUFFLE BUTTON
            Button {
                Task {
                    if isAlbumCurrentlyLoaded {
                        playerVM.toggleShuffle()
                    } else {
                        await shuffleAlbum()
                    }
                }
            } label: {
                HStack(spacing: DSLayout.contentGap) {
                    Image(systemName: playerVM.isShuffling ? "shuffle" : "arrow.right")
                        .font(DSText.emphasized)
                    Text("Shuffle")
                        .font(DSText.emphasized)
                }
                .foregroundStyle(playerVM.isShuffling ? .white : .orange)
                .padding(.horizontal, DSLayout.contentPadding)
                .padding(.vertical, DSLayout.elementPadding)
                .background(
                    Capsule()
                        .fill(playerVM.isShuffling ? .orange : .black.opacity(0.4))
                        .overlay(Capsule().stroke(.orange, lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
                )
            }

            // DOWNLOAD BUTTON (Neu: Managed sich selbst & zeigt Progress)
            DownloadButton(album: album, songs: songs)
        }
    }
    


    private func playAlbum() async {
        guard !songs.isEmpty else { return }
        await playerVM.setPlaylist(songs, startIndex: 0, albumId: album.id)
    }

    private func shuffleAlbum() async {
        guard !songs.isEmpty else { return }
        let shuffledSongs = songs.shuffled()
        await playerVM.setPlaylist(shuffledSongs, startIndex: 0, albumId: album.id)
        if !playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }

    private func buildMetadataString() -> String {
        var parts: [String] = []
        if !songs.isEmpty { parts.append("\(songs.count) Song\(songs.count != 1 ? "s" : "")") }
        if let duration = album.duration { parts.append(formatDuration(duration)) }
        if let year = album.year { parts.append("\(year)") }
        return parts.joined(separator: " • ")
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
    
    private var isAlbumCurrentlyLoaded: Bool {
        return playerVM.currentAlbumId == album.id && !playerVM.currentPlaylist.isEmpty
    }
}
