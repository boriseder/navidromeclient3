//
//  DownloadButton.swift
//  NavidromeClient3
//
//  Swift 6: Restored Progress Circle & Fixed Method Calls
//

import SwiftUI

struct DownloadButton: View {
    let song: Song
    @Environment(DownloadManager.self) private var downloadManager
    
    // FIX: Computed property to check progress safely
    private var downloadProgress: Double? {
        downloadManager.activeDownloads[song.id]
    }
    
    var body: some View {
        Group {
            if downloadManager.isSongDownloaded(song.id) {
                // State: Downloaded
                Button {
                    // Optional: Add delete action or simple feedback
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.title3)
                }
                .disabled(true) // Disable to prevent accidental re-download
                
            } else if let progress = downloadProgress {
                // State: Downloading (Restored Progress Circle)
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: progress)
                    
                    // Stop Button
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 24, height: 24)
                // Add tap to cancel if desired
                
            } else {
                // State: Not Downloaded
                Button {
                    Task {
                        // FIX: Use correct method name 'downloadSong'
                        await downloadManager.downloadSong(song)
                    }
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(Color.primary)
                        .font(.title3)
                }
            }
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
