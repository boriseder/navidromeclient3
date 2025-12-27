import SwiftUI

struct DownloadButton: View {
    let song: Song
    @Environment(DownloadManager.self) private var downloadManager
    
    var body: some View {
        Button {
            Task { await downloadManager.download(song: song) }
        } label: {
            Image(systemName: downloadManager.isDownloaded(song.id) ? "checkmark.circle" : "arrow.down.circle")
        }
    }
}

// Ensure extensions exist
extension Notification.Name {
    static let downloadCompleted = Notification.Name("downloadCompleted")
    static let downloadDeleted = Notification.Name("downloadDeleted")
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
