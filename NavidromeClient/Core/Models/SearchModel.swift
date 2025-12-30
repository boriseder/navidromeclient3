import SwiftUI

struct SearchContainer: Codable, Sendable {
    let searchResult2: SearchResult2
}

struct SearchResult2: Codable, Sendable {
    let artist: [Artist]?
    let album: [Album]?
    let song: [Song]?
}

struct SearchResult: Sendable {
    let artists: [Artist]
    let albums: [Album]
    let songs: [Song]
}
