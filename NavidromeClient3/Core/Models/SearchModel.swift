//
//  SearchModel.swift
//  NavidromeClient3
//
//  Swift 6: Pure Data Model (Sendable, No UI)
//

import Foundation

// MARK: - Search Container
struct SearchContainer: Codable, Sendable {
    let searchResult2: SearchResult2
}

struct SearchResult2: Codable, Sendable {
    let artist: [Artist]?
    let album: [Album]?
    let song: [Song]?
}

// MARK: - SearchResult DTO
struct SearchResult: Sendable {
    let artists: [Artist]
    let albums: [Album]
    let songs: [Song]
    
    var isEmpty: Bool {
        artists.isEmpty && albums.isEmpty && songs.isEmpty
    }
}
