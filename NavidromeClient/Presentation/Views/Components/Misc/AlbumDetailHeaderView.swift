//
//  AlbumDetailHeaderView.swift
//  NavidromeClient
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
    @Environment(ThemeManager.self) var theme

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
                    .foregroundStyle(theme.textColor)
                    .shadow(color: theme.textColor.opacity(0.2), radius: 1, x: 0, y: 1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(album.artist)
                    .font(DSText.prominent)
                    .foregroundStyle(theme.textColor.opacity(0.95))
                    .shadow(color: theme.textColor.opacity(0.2), radius: 1, x: 0, y: 1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(buildMetadataString())
                    .font(DSText.metadata)
                    .foregroundStyle(theme.textColor.opacity(0.7))
                    .shadow(color: theme.textColor.opacity(0.2), radius: 1, x: 0, y: 1)
                    .multilineTextAlignment(.leading)

                AlbumActionBar(album: album, songs: songs, isOfflineAlbum: isOfflineAlbum)

                Spacer()
            }
        }
    }

    // MARK: - Helpers

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
}
