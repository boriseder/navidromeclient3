//
//  AlbumDetailView.swift
//  NavidromeClient3
//
//  Swift 6: Restored Data Loading via SongManager & Added Background
//

import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    
    // MARK: - Environment
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(SongManager.self) private var songManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(OfflineManager.self) private var offlineManager
    
    // MARK: - State
    @State private var songs: [Song] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Header
                AlbumDetailHeaderView(album: album)
                    .padding(.top, 20)
                
                // 2. Action Buttons
                HStack(spacing: 20) {
                    // PLAY BUTTON
                    Button {
                        playerVM.playQueue(songs: songs, startIndex: 0)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(songs.isEmpty)
                    
                    // DOWNLOAD BUTTON
                    Button {
                        Task {
                            await downloadManager.downloadAlbum(album: album, songs: songs)
                        }
                    } label: {
                        Label(
                            downloadManager.isAlbumDownloaded(album.id) ? "Downloaded" : "Download",
                            systemImage: downloadManager.isAlbumDownloaded(album.id) ? "checkmark.circle.fill" : "arrow.down.circle"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(songs.isEmpty || downloadManager.isAlbumDownloaded(album.id))
                }
                .padding(.horizontal)
                
                // 3. Songs List
                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if let error = errorMessage {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    AlbumSongsListView(songs: songs, album: album)
                }
            }
            .padding(.bottom, 100)
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        // FIX: Add dynamic blurred background using the album cover
        .background(
            DynamicMusicBackground(albumId: album.coverArt ?? album.id)
        )
        .task {
            await loadSongs()
        }
        .refreshable {
            await loadSongs()
        }
    }
    
    // MARK: - Data Loading
    private func loadSongs() async {
        // 1. Offline Mode Check
        if !networkMonitor.isConnected {
            let offlineSongs = offlineManager.getOfflineSongs().filter { $0.albumId == album.id }
            if !offlineSongs.isEmpty {
                self.songs = offlineSongs.sorted { ($0.track ?? 0) < ($1.track ?? 0) }
                return
            }
            self.errorMessage = "Offline: Cannot load songs"
            return
        }
        
        // 2. Online Load
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedSongs = try await songManager.getSongs(for: album.id)
            self.songs = fetchedSongs.sorted { ($0.track ?? 0) < ($1.track ?? 0) }
            
        } catch {
            self.errorMessage = "Failed to load songs: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
