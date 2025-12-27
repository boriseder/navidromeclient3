import SwiftUI

struct CoverArtDebugView: View {
    // FIX: Swift 6 Environment
    @Environment(CoverArtManager.self) private var coverArtManager
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Cover Art Diagnostics").font(.headline)
            Text("Cache Gen: \(coverArtManager.cacheGeneration)")
            Button("Clear Cache") {
                coverArtManager.clearMemoryCache()
            }
        }
        .padding()
    }
}
