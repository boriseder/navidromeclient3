import SwiftUI

struct GenreView: View {
    // FIX: Swift 6 Environment
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(AppConfig.self) private var appConfig
    @Environment(ThemeManager.self) private var theme
    @Environment(MusicLibraryManager.self) private var musicLibraryManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(OfflineManager.self) private var offlineManager
    
    @State private var debouncer = Debouncer(delay: 0.5)
    
    var body: some View {
        List {
            ForEach(musicLibraryManager.loadedGenres) { genre in
                Text(genre.value)
            }
        }
        .searchable(text: $debouncer.input)
        .navigationTitle("Genres")
        .task {
            await musicLibraryManager.loadGenresProgressively()
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

