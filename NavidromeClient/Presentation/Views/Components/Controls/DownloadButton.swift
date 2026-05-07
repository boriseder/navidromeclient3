import SwiftUI

struct DownloadButton: View {
    let album: Album
    let songs: [Song]
    
    @Environment(DownloadManager.self) var downloadManager
    
    var body: some View {
        // Direkter Zugriff auf die reaktiven Properties des DownloadManagers
        let state = downloadManager.getDownloadState(for: album.id)
        let progress = downloadManager.downloadProgress[album.id] ?? 0.0
        
        Button {
            handleButtonTap(state: state)
        } label: {
            ZStack {
                switch state {
                case .idle, .error:
                    Image(systemName: "arrow.down")
                        .font(DSText.largeButton)
                
                case .downloading:
                    ZStack {
                        // Hintergrund-Ring
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 2)
                        
                        // Progress-Donut
                        Circle()
                            .trim(from: 0, to: max(0.05, progress))
                            .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.2), value: progress)
                        
                        // Stop-Icon
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    
                case .downloaded:
                    Image(systemName: "checkmark")
                        .font(DSText.largeButton)
                    
                case .cancelling:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
            }
            .foregroundStyle(state == .downloaded ? .white : .blue)
            // Passe die Größen an dein DSLayout an
            .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
            .background(
                Circle()
                    .fill(state == .downloaded ? .blue : .black)
                    .overlay(Circle().stroke(.blue, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
            )
        }
        .disabled(state == .cancelling)
    }
    
    // MARK: - Actions & Haptics
    
    private func handleButtonTap(state: DownloadManager.DownloadState) {
        // Haptisches Feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        switch state {
        case .idle, .error:
            AppLogger.ui.info("[DownloadButton] Starte Download für: \(album.id)")
            Task {
                await downloadManager.startDownload(album: album, songs: songs)
            }
        case .downloading:
            AppLogger.ui.info("[DownloadButton] Breche Download ab für: \(album.id)")
            downloadManager.cancelDownload(albumId: album.id)
        case .downloaded:
            AppLogger.ui.info("[DownloadButton] Lösche Download für: \(album.id)")
            downloadManager.deleteDownload(albumId: album.id)
        case .cancelling:
            break
        }
    }
}
