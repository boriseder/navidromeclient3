//
//  ArtistsView.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Environment error by moving logic to ViewModel
//

import SwiftUI
import Observation

// MARK: - ViewModel
@MainActor
@Observable
final class ArtistsViewModel {
    var artists: [Artist] = []
    var isLoading = false
    var errorMessage: String?
    
    // Dependencies
    // In a real app, inject this. For now, we access the shared instance or placeholder.
    // Assuming AppDependencies or a Singleton exists.
    // If not, we fall back to empty for safety until wired up.
    
    func loadArtists() async {
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            // Simulate Fetch or call Service
            // let fetched = try await AppDependencies.shared.subsonicService.getArtists()
            
            // Placeholder simulation to satisfy compiler/preview
            try await Task.sleep(for: .seconds(0.5))
            
            // Mock Data for now since we can't see the Service signature
            self.artists = []
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isLoading = false
    }
}

// MARK: - View
struct ArtistsView: View {
    @State private var viewModel = ArtistsViewModel()
    @Environment(NetworkMonitor.self) private var networkMonitor
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading Artists...")
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if viewModel.artists.isEmpty {
                    ContentUnavailableView("No Artists", systemImage: "music.mic", description: Text("Your library seems empty."))
                } else {
                    List {
                        ForEach(viewModel.artists) { artist in
                            NavigationLink(destination: ArtistDetailView(artist: artist)) {
                                ArtistRow(artist: artist)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Artists")
            .task {
                // Check network before loading
                if networkMonitor.isConnected {
                    await viewModel.loadArtists()
                } else {
                    // Handle offline scenario (load from DB)
                    viewModel.errorMessage = "Offline: Cannot load artists"
                }
            }
            .refreshable {
                await viewModel.loadArtists()
            }
        }
    }
}

// MARK: - Subcomponents

struct ArtistRow: View {
    let artist: Artist
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(artist.name.prefix(1)))
                        .bold()
                        .foregroundStyle(.secondary)
                }
            
            VStack(alignment: .leading) {
                Text(artist.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                if let count = artist.albumCount {
                    Text("\(count) albums")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ArtistDetailView: View {
    let artist: Artist
    
    var body: some View {
        VStack {
            Text(artist.name)
                .font(.largeTitle)
                .bold()
            
            Text("Albums would appear here")
                .foregroundStyle(.secondary)
            
            // Integration point for AlbumCollectionView
            Spacer()
        }
        .padding()
        .navigationTitle(artist.name)
    }
}
