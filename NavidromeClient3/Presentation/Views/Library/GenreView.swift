//
//  GenreViewContent.swift - UPDATED: Unified State System
//  NavidromeClient
//
//   UNIFIED: Single ContentLoadingStrategy for consistent state
//   CLEAN: Simplified toolbar and state management
//   FIXED: Proper refresh method names and error handling
//

import SwiftUI

struct GenreView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    @State private var searchText = ""
    @StateObject private var debouncer = Debouncer()
    
    // MARK: - UNIFIED: Single State Logic
    
    private var displayedGenres: [Genre] {
        let genres: [Genre]
        
        switch networkMonitor.contentLoadingStrategy {
        case .online:
            genres = filterGenres(musicLibraryManager.genres)
        case .offlineOnly:
            genres = filterGenres(offlineManager.offlineGenres)
        case .setupRequired:
            genres = []
        }
        
        return genres
    }
    
    
    var body: some View {
        NavigationStack {
            ZStack {

                if theme.backgroundStyle == .dynamic {
                    DynamicMusicBackground()
                }
                
                contentView
            }
            .navigationTitle("Genres")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(
                theme.colorScheme,
                for: .navigationBar
            )
            .searchable(text: $searchText, prompt: "Search genres...")
            .refreshable {
                guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
                await refreshAllData()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                    }
                }
            }
            .navigationDestination(for: Genre.self) { genre in
                AlbumCollectionView(context: .byGenre(genre))
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.contentGap) {
                ForEach(displayedGenres.indices, id: \.self) { index in
                    let genre = displayedGenres[index]
                    
                    NavigationLink(value: genre) {
                        GenreRowView(genre: genre, index: index)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, DSLayout.miniPlayerHeight)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, DSLayout.screenPadding)
    }
    
    // MARK: - Business Logic
    
    private func filterGenres(_ genres: [Genre]) -> [Genre] {
        let filteredGenres: [Genre]
        
        if searchText.isEmpty {
            filteredGenres = genres
        } else {
            filteredGenres = genres.filter { genre in
                genre.value.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filteredGenres.sorted(by: { $0.value < $1.value })
    }

    private func refreshAllData() async {
        await musicLibraryManager.refreshAllData()
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            // Search filtering happens automatically via computed property
        }
    }
}

// MARK: - Genre Row View

struct GenreRowView: View {
    let genre: Genre
    let index: Int
   
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.2),
                                .white.opacity(0.08),
                                .white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: ImageContext.artistList.displaySize, height: ImageContext.artistList.displaySize)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .white.opacity(0.1), radius: 4, x: 0, y: 2)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: DSLayout.smallIcon))
                    .foregroundStyle(DSColor.onDark)
            }
            .padding(.vertical, DSLayout.tightPadding)
            .padding(.leading, DSLayout.tightPadding)
            
            // Genre Info
            Text(genre.value)
                .font(DSText.emphasized)
                .foregroundStyle(DSColor.onDark)
                .lineLimit(1)
            
            Spacer()
            
            Image(systemName: "record.circle")
                .font(DSText.fine)
                .foregroundStyle(DSColor.onDark)
            
            Text("\(genre.albumCount) Album\(genre.albumCount != 1 ? "s" : "")")
                .font(DSText.metadata)
                .foregroundStyle(DSColor.onDark)
                .padding(.trailing, DSLayout.contentPadding)
        }
        .background(theme.backgroundContrastColor.opacity(0.12))
    }
    
}

