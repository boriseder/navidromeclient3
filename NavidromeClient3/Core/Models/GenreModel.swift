//
//  GenreModel.swift
//  NavidromeClient3
//
//  Swift 6: Full Concurrency Support
//

struct GenresContainer: Codable, Sendable {
    let genres: GenreList?
}

struct GenreList: Codable, Sendable {
    let genre: [Genre]?
}

struct Genre: Identifiable, Hashable, Codable, Sendable {
    var id: String { value }
    let value: String
    let songCount: Int?
    let albumCount: Int
    
    enum CodingKeys: String, CodingKey {
        case value, songCount, albumCount
    }
}
