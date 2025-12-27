import SwiftUI

struct AlbumsView: View {
    @Environment(MusicLibraryManager.self) private var library
    
    // FIX: Use global AlbumSortType
    @State private var sortType: AlbumSortType = .alphabetical
    
    var body: some View {
        ScrollView {
            // Implementation...
            Text("Albums")
        }
        .navigationTitle("Albums")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sortType) {
                        ForEach(AlbumSortType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
        }
        .onChange(of: sortType) { _, newSort in
            Task { await library.loadAlbumsProgressively(sortBy: newSort, reset: true) }
        }
    }
}
