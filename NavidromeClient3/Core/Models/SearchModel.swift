//  SearchModel.swift
//  NavidromeClient3
//
//  Swift 6: Full Concurrency Support
//

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
    
    var isEmpty: Bool {
        artists.isEmpty && albums.isEmpty && songs.isEmpty
    }
}
