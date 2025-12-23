import SwiftUI

// MARK: - Search
struct SearchContainer: Codable {
    let searchResult2: SearchResult2
}

struct SearchResult2: Codable {
    let artist: [Artist]?
    let album: [Album]?
    let song: [Song]?
}

// MARK: - SearchResult DTO (für Service)
struct SearchResult {
    let artists: [Artist]
    let albums: [Album]
    let songs: [Song]
}
