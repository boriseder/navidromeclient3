//
//  DownloadButton.swift
//  NavidromeClient3
//
//  Swift 6: Restored Progress Circle
//

import SwiftUI

struct DownloadButton: View {
    let song: Song
    @Environment(DownloadManager.self) private var downloadManager
    
    // This helper explicitly asks the manager for the value in the dictionary.
    // Since activeDownloads is [String: Double], this returns Double?
    private var downloadProgress: Double? {
        downloadManager.activeDownloads[song.id]
    }
    
    var body: some View {
        Group {
            // Check if downloaded using the method exposed by DownloadManager
            if downloadManager.isSongDownloaded(song.id) {
                // State: Downloaded
                Button {
                    // Optional: Add delete action or feedback
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.title3)
                }
                .disabled(true)
                
            } else if let progress = downloadProgress {
                // State: Downloading (Progress Circle)
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
                .onTapGesture {
                    // Optional: Add cancel logic here
                }
                
            } else {
                // State: Not Downloaded
                Button {
                    Task {
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
