//
//  AlbumDetailView.swift
//  NavidromeClient3
//
//  Swift 6: Restored Immersive Background
//

import SwiftUI

struct AlbumDetailView: View {
    let album: NavidromeClient3.Album
    
    @Environment(SongManager.self) private var songManager
    @Environment(PlayerViewModel.self) private var player
    @Environment(CoverArtManager.self) private var coverArtManager
    
    @State private var songs: [Song] = []
    @State private var isLoading = false
    @State private var backgroundImage: UIImage?
    
    var body: some View {
        ZStack {
            // MARK: - Background Layer
            if let bg = backgroundImage {
                GeometryReader { geo in
                    Image(uiImage: bg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 60)
                        .overlay(Color.black.opacity(0.4))
                }
                .ignoresSafeArea()
                .transition(.opacity)
            } else {
                Color.black.ignoresSafeArea() // Fallback
            }
            
            // MARK: - Content
            ScrollView {
                VStack(spacing: 0) {
                    AlbumDetailHeaderView(album: album)
                        .padding(.bottom, DSLayout.sectionGap)
                    
                    if isLoading {
                        VStack(spacing: 16) {
                            ForEach(0..<5) { _ in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 50)
                            }
                        }
                        .padding()
                        .shimmering()
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                                SongRow(song: song, trackNumber: index + 1, isPlaying: player.currentSong?.id == song.id)
                                    .onTapGesture {
                                        Task { await player.play(song: song, context: songs) }
                                    }
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isLoading = true
            
            // Load Content
            async let fetchedSongs = songManager.getSongs(for: album.id)
            async let fetchedImage = coverArtManager.loadAlbumImage(for: album.id, context: .fullscreen)
            
            let (s, i) = await (fetchedSongs, fetchedImage)
            
            self.songs = s
            withAnimation { self.backgroundImage = i }
            
            isLoading = false
        }
    }
}
