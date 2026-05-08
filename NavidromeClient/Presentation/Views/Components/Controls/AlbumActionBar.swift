//
//  AlbumActionBar.swift
//  NavidromeClient
//
//  Created by EDER Boris (ICS480-ECC) on 08.05.26.
//


//
//  AlbumActionBar.swift
//  NavidromeClient
//
//  Extracted from AlbumDetailHeaderView.
//  Three actions: Play, Shuffle, Download — restrained dark style.
//

import SwiftUI

struct AlbumActionBar: View {
    let album: Album
    let songs: [Song]
    let isOfflineAlbum: Bool

    @Environment(PlayerViewModel.self) var playerVM
    @Environment(ThemeManager.self) var theme

    var body: some View {
        HStack(spacing: 10) {
            // ── Play ────────────────────────────────────────────────────
            ActionPillButton(
                icon: playerVM.isPlaying && isAlbumCurrentlyLoaded ? "pause.fill" : "play.fill",
                label: playerVM.isPlaying && isAlbumCurrentlyLoaded ? "Pause" : "Play",
                isActive: playerVM.isPlaying && isAlbumCurrentlyLoaded,
                accentColor: theme.accent
            ) {
                Task {
                    if isAlbumCurrentlyLoaded {
                        playerVM.togglePlayPause()
                    } else {
                        await playAlbum()
                    }
                }
            }

            // ── Shuffle ─────────────────────────────────────────────────
            ActionPillButton(
                icon: "shuffle",
                label: "Shuffle",
                isActive: playerVM.isShuffling && isAlbumCurrentlyLoaded,
                accentColor: theme.accent
            ) {
                Task {
                    if isAlbumCurrentlyLoaded {
                        playerVM.toggleShuffle()
                    } else {
                        await shuffleAlbum()
                    }
                }
            }

            // ── Download (secondary, icon-only) ─────────────────────────
            DownloadButton(album: album, songs: songs)
        }
    }

    // MARK: - Helpers

    private var isAlbumCurrentlyLoaded: Bool {
        playerVM.currentAlbumId == album.id && !playerVM.currentPlaylist.isEmpty
    }

    private func playAlbum() async {
        guard !songs.isEmpty else { return }
        await playerVM.setPlaylist(songs, startIndex: 0, albumId: album.id)
    }

    private func shuffleAlbum() async {
        guard !songs.isEmpty else { return }
        let shuffled = songs.shuffled()
        await playerVM.setPlaylist(shuffled, startIndex: 0, albumId: album.id)
        if !playerVM.isShuffling { playerVM.toggleShuffle() }
    }
}

// MARK: - ActionPillButton

/// Equal-width pill for Play and Shuffle.
/// Inactive: dark frosted glass with subtle white border.
/// Active: filled with theme accent, white label.
struct ActionPillButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let accentColor: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isActive ? .black : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                Capsule()
                    .fill(isActive ? accentColor : Color.white.opacity(0.1))
                    .overlay {
                        Capsule()
                            .stroke(
                                isActive ? Color.clear : Color.white.opacity(0.18),
                                lineWidth: 1
                            )
                    }
            }
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
            .animation(.easeInOut(duration: 0.15), value: isActive)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}