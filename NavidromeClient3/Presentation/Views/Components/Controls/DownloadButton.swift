import SwiftUI

struct DownloadButton: View {
    let song: Song
    
    // FIX: Swift 6 Environment
    @Environment(DownloadManager.self) private var downloadManager
    
    // Helper state for UI logic
    private var downloadState: DownloadState {
        if downloadManager.isDownloaded(song.id) {
            return .downloaded
        }
        if let progress = downloadManager.activeDownloads[song.id] {
            return .downloading(progress)
        }
        return .notDownloaded
    }
    
    var body: some View {
        Button {
            handleAction()
        } label: {
            iconView
        }
        .disabled(isDownloading)
    }
    
    private var isDownloading: Bool {
        if case .downloading = downloadState { return true }
        return false
    }
    
    private func handleAction() {
        switch downloadState {
        case .notDownloaded:
            Task { await downloadManager.download(song: song) }
        case .downloaded:
            downloadManager.deleteDownload(for: song.id)
        case .downloading:
            break
        }
    }
    
    @ViewBuilder
    private var iconView: some View {
        switch downloadState {
        case .notDownloaded:
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 20))
        case .downloading(let progress):
            ZStack {
                CircularProgressView(progress: progress)
                    .frame(width: 24, height: 24)
                Image(systemName: "stop.fill")
                    .font(.system(size: 10))
            }
        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
        }
    }
}

// FIX: Helper Enum
enum DownloadState: Equatable {
    case notDownloaded
    case downloading(Double)
    case downloaded
}

// Simple Circular Progress Helper
struct CircularProgressView: View {
    let progress: Double
    var body: some View {
        Circle()
            .trim(from: 0, to: CGFloat(progress))
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}
