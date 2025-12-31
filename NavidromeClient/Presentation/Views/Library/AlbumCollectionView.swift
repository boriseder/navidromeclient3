import SwiftUI

enum AlbumCollectionContext: Sendable {
    case byArtist(Artist)
    case byGenre(Genre)
}

struct AlbumCollectionView: View {
    let context: AlbumCollectionContext
    
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var theme: ThemeManager

    @State private var albums: [Album] = []
    @State private var backgroundImageLoaded = false

    private var displayedAlbums: [Album] {
        return networkMonitor.shouldLoadOnlineContent ? albums : availableOfflineAlbums
    }
    
    private var availableOfflineAlbums: [Album] {
        switch context {
        case .byArtist(let artist): return offlineManager.getOfflineAlbums(for: artist)
        case .byGenre(let genre): return offlineManager.getOfflineAlbums(for: genre)
        }
    }
    
    private var contextTitle: String {
        switch context {
        case .byArtist(let artist): return artist.name
        case .byGenre(let genre): return genre.value
        }
    }
    
    var body: some View {
        ZStack {
            if case .byArtist(let artist) = context, backgroundImageLoaded {
                artistBlurredBackground(for: artist).transition(.opacity)
            }
            theme.backgroundColor.opacity(0.3).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    if case .byArtist = context { artistHeroHeader }
                    else if case .byGenre = context { genreHeroHeader }
                    contentView.padding(.top, DSLayout.contentPadding)
                }
                .padding(.horizontal, DSLayout.screenPadding)
                .padding(.bottom, DSLayout.miniPlayerHeight)
                .padding(.top, -40)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
            .scrollIndicators(.hidden)
            .task {
                if case .byArtist(let artist) = context { await loadBackgroundImage(for: artist) }
                await loadContent()
            }
            .refreshable {
                guard networkMonitor.shouldLoadOnlineContent else { return }
                await loadContent()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: backgroundImageLoaded)
    }
    
    @MainActor
    private func loadBackgroundImage(for artist: Artist) async {
        if coverArtManager.getArtistImage(for: artist.id, context: .fullscreen) != nil {
            backgroundImageLoaded = true
            return
        }
        let image = await coverArtManager.loadArtistImage(for: artist.id, context: .fullscreen)
        if image != nil { backgroundImageLoaded = true }
    }
    
    @ViewBuilder
    private var contentView: some View {
        LazyVGrid(columns: GridColumns.two, alignment: .leading, spacing: DSLayout.elementGap) {
            ForEach(displayedAlbums.indices, id: \.self) { index in
                let album = displayedAlbums[index]
                NavigationLink(value: album) {
                    CardItemContainer(content: .album(album), index: index)
                }
            }
        }
    }
    
    @MainActor
    private func loadContent() async {
        do {
            albums = try await musicLibraryManager.loadAlbums(context: context)
        } catch {
            albums = availableOfflineAlbums
        }
    }
    
    private func playAllAlbums() async {
        let albumsToPlay = displayedAlbums
        guard !albumsToPlay.isEmpty else { return }
        var allSongs: [Song] = []
        for album in albumsToPlay {
            let songs = await songManager.loadSongs(for: album.id)
            allSongs.append(contentsOf: songs)
        }
        guard !allSongs.isEmpty else { return }
        await playerVM.setPlaylist(allSongs, startIndex: 0, albumId: nil)
        if playerVM.isShuffling { playerVM.toggleShuffle() }
    }
    
    private func shuffleAllAlbums() async {
        let albumsToPlay = displayedAlbums
        guard !albumsToPlay.isEmpty else { return }
        var allSongs: [Song] = []
        for album in albumsToPlay {
            let songs = await songManager.loadSongs(for: album.id)
            allSongs.append(contentsOf: songs)
        }
        guard !allSongs.isEmpty else { return }
        let shuffledSongs = allSongs.shuffled()
        await playerVM.setPlaylist(shuffledSongs, startIndex: 0, albumId: nil)
        if !playerVM.isShuffling { playerVM.toggleShuffle() }
    }
    
    private var albumCountText: String {
        let count = displayedAlbums.count
        switch context {
        case .byArtist: return "\(count) Album\(count != 1 ? "s" : "")"
        case .byGenre: return "\(count) Album\(count != 1 ? "s" : "") in this genre"
        }
    }
    
    @ViewBuilder
    private func artistBlurredBackground(for artist: Artist) -> some View {
        Color.clear
            .overlay(
                ArtistImageView(artist: artist, context: .fullscreen)
                    .frame(width: CGFloat(ImageContext.fullscreen.size), height: CGFloat(ImageContext.fullscreen.size))
                    .blur(radius: 20)
                    .scaleEffect(1.5)
                    .offset(y: -100)
            )
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(0.7), .black.opacity(0.35), .black.opacity(0.2), .black.opacity(0.3), .black.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .ignoresSafeArea()
    }
    
    @ViewBuilder
    private var artistHeroHeader: some View {
        VStack {
            // FIX: Correctly extract artist from context enum
            if case .byArtist(let artist) = context {
                ArtistImageView(artist: artist, context: .detail)
                    .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 10)
                    .shadow(color: .black.opacity(0.3), radius: 40, x: 0, y: 20)
            }
            
            VStack(spacing: DSLayout.elementGap) {
                Text(contextTitle).font(DSText.pageTitle).foregroundStyle(.white).lineLimit(2).multilineTextAlignment(.center)
                Text(albumCountText).font(DSText.detail).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
            }
            actionButtonsFloating
            Spacer()
        }
    }
    
    @ViewBuilder
    private var genreHeroHeader: some View {
        VStack {
            Text(contextTitle).font(DSText.pageTitle).foregroundStyle(DSColor.onDark).lineLimit(2).multilineTextAlignment(.center)
            Text(albumCountText).font(DSText.detail).foregroundStyle(DSColor.onDark).lineLimit(1)
        }
    }
    
    @ViewBuilder
    private var actionButtonsFloating: some View {
        HStack(spacing: DSLayout.contentGap) {
            Button { Task { await playAllAlbums() } } label: {
                HStack(spacing: DSLayout.contentGap) {
                    Image(systemName: "play.fill").font(DSText.emphasized)
                    Text("Play All").font(DSText.emphasized)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DSLayout.contentPadding)
                .padding(.vertical, DSLayout.elementPadding)
                .background(Capsule().fill(LinearGradient(colors: [Color(red: 0.2, green: 0.8, blue: 0.2), Color(red: 0.15, green: 0.7, blue: 0.15)], startPoint: .top, endPoint: .bottom)))
            }
            Button { Task { await shuffleAllAlbums() } } label: {
                HStack(spacing: DSLayout.contentGap) {
                    Image(systemName: "shuffle").font(DSText.emphasized)
                    Text("Shuffle").font(DSText.emphasized)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DSLayout.contentPadding)
                .padding(.vertical, DSLayout.elementPadding)
                .background(Capsule().fill(LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.15)], startPoint: .top, endPoint: .bottom)).overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1)))
            }
        }
    }
}
