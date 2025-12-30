//
//  AlbumCollectionView.swift
//  NavidromeClient
//
//  Fixed: Removed conflicting navigationDestination
//

import SwiftUI

enum AlbumCollectionContext {
    case byArtist(Artist)
    case byGenre(Genre)
}

struct AlbumCollectionView: View {
    let albums: [Album] // Online albums passed in
    
    @Environment(OfflineManager.self) private var offlineManager
    @Environment(DownloadManager.self) private var downloadManager
    
    var displayAlbums: [Album] {
        if offlineManager.isOfflineMode {
            // FIX: This method now exists and returns [Album]
            return offlineManager.getOfflineAlbums()
        } else {
            return albums
        }
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(displayAlbums) { album in
                    NavigationLink(destination: AlbumDetailView(album: album)) {
                        VStack(alignment: .leading, spacing: 8) {
                            // Cover Art
                            AlbumImageView(album: album, context: .grid)
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(radius: 4)
                            
                            // Text Info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(album.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                
                                Text(album.artist)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .overlay {
            if displayAlbums.isEmpty {
                ContentUnavailableView(
                    offlineManager.isOfflineMode ? "No Offline Albums" : "No Albums Found",
                    systemImage: "music.note.list",
                    description: Text(offlineManager.isOfflineMode ? "Download albums to listen offline." : "Try syncing your library.")
                )
            }
        }
    }
}
