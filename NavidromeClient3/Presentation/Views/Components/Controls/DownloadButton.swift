//
//  DownloadButton.swift - FIXED: Proper State Observation
//  NavidromeClient
//
//  FIXED: Direct state observation with objectWillChange
//  FIXED: Multiple download prevention
//

import SwiftUI

struct DownloadButton: View {
    let album: Album
    let songs: [Song]
    
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var showingDeleteConfirmation = false
    @State private var isProcessing = false
    
    @State private var currentState: DownloadManager.DownloadState = .idle
    @State private var currentProgress: Double = 0.0
    
    var body: some View {
        Button {
            handleButtonTap()
        } label: {
            buttonContent
        }
        .disabled(isProcessing)
        .onAppear {
            updateState()
        }
        .onReceive(downloadManager.objectWillChange) { _ in
            updateState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadCompleted)) { notification in
            if let albumId = notification.object as? String, albumId == album.id {
                updateState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadDeleted)) { notification in
            if let albumId = notification.object as? String, albumId == album.id {
                updateState()
            }
        }
        .confirmationDialog(
            "Delete Downloaded Album?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteDownload()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the downloaded songs from your device.")
        }
    }
    
    private func updateState() {
        currentState = downloadManager.getDownloadState(for: album.id)
        currentProgress = downloadManager.downloadProgress[album.id] ?? 0.0
    }
    
    @ViewBuilder
    private var buttonContent: some View {
        HStack(spacing: 8) {
            Group {
                switch currentState {
                case .idle:
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 18, weight: .medium))
                case .downloading:
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 2)
                        
                        Circle()
                            .trim(from: 0, to: max(0.05, currentProgress))
                            .stroke(.white, lineWidth: 2)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.2), value: currentProgress)
                        
                        Text("\(Int(max(0.05, currentProgress) * 100))%")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.white)
                    }
                case .downloaded:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                case .error:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18, weight: .medium))
                case .cancelling:
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white)
                }
            }
            .frame(width: 20, height: 20)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(buttonBackgroundColor)
        .clipShape(Capsule())
        .shadow(radius: 4)
    }
    
    private var buttonBackgroundColor: Color {
        switch currentState {
        case .idle, .downloading: return .blue
        case .downloaded: return .green
        case .error: return .red
        case .cancelling: return .gray
        }
    }
    
    private func handleButtonTap() {
        guard !isProcessing else { return }
        
        switch currentState {
        case .idle, .error:
            startDownload()
        case .downloading:
            cancelDownload()
        case .downloaded:
            showingDeleteConfirmation = true
        case .cancelling:
            break
        }
    }
    
    private func startDownload() {
        guard !isProcessing else { return }
        
        isProcessing = true
        Task {
            await downloadManager.startDownload(album: album, songs: songs)
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func cancelDownload() {
        downloadManager.cancelDownload(albumId: album.id)
    }
    
    private func deleteDownload() {
        downloadManager.deleteDownload(albumId: album.id)
    }
}
