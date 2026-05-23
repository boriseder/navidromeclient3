//
//  DownloadButton.swift
//  NavidromeClient
//
//  Icon-only secondary action. Steps back visually next to the two primary pills.
//  Same frosted-glass language, no loud color fill when idle.
//

import SwiftUI

struct DownloadButton: View {
    let album: Album
    let songs: [Song]

    @Environment(DownloadManager.self) var downloadManager

    var body: some View {
        let state = downloadManager.getDownloadState(for: album.id)
        let progress = downloadManager.downloadProgress[album.id] ?? 0.0

        Button {
            handleTap(state: state)
        } label: {
            ZStack {
                // Background circle — matches pill style
                Circle()
                    .fill(state == .downloaded ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                    .overlay {
                        Circle()
                            .stroke(
                                state == .downloaded
                                    ? Color.white.opacity(0.35)
                                    : Color.white.opacity(0.18),
                                lineWidth: 1
                            )
                    }
                    .frame(width: 44, height: 44)

                // Icon layer
                switch state {
                case .idle:
                    Image(systemName: "arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                case .error:
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.red.opacity(0.8))  // or an exclamationmark.triangle
                case .downloading:
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                            .frame(width: 22, height: 22)

                        Circle()
                            .trim(from: 0, to: max(0.05, progress))
                            .stroke(
                                Color.white,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .frame(width: 22, height: 22)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.2), value: progress)

                        Image(systemName: "stop.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                case .downloaded:
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                case .cancelling:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.75)
                }
            }
        }
        .frame(width: 44, height: 44)
        .disabled(state == .cancelling)
        .buttonStyle(ScaleButtonStyle())
        .animation(.easeInOut(duration: 0.15), value: state)
    }

    // MARK: - Actions

    private func handleTap(state: DownloadManager.DownloadState) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        switch state {
        case .idle, .error:
            Task { await downloadManager.startDownload(album: album, songs: songs) }
        case .downloading:
            downloadManager.cancelDownload(albumId: album.id)
        case .downloaded:
            downloadManager.deleteDownload(albumId: album.id)
        case .cancelling:
            break
        }
    }
}
