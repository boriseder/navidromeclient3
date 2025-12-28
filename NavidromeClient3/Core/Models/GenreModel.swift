//
//  GenreModel.swift
//  NavidromeClient3
//
//  Swift 6: Full Concurrency Support
//

import Foundation

nonisolated struct GenresContainer: Codable, Sendable {
    let genres: GenreList?
}

nonisolated struct GenreList: Codable, Sendable {
    let genre: [Genre]?
}

nonisolated struct Genre: Identifiable, Hashable, Codable, Sendable {
    var id: String { value }
    let value: String
    let songCount: Int?
    let albumCount: Int
    
    enum CodingKeys: String, CodingKey {
        case value, songCount, albumCount
    }
}
