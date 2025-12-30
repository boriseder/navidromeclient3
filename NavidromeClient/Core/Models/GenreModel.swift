import SwiftUI

struct GenresContainer: Codable, Sendable {
    let genres: GenreList?
}

struct GenreList: Codable, Sendable {
    let genre: [Genre]?
}

struct Genre: Identifiable, Hashable, Codable, Sendable {
    var id: String { value }
    let value: String
    let songCount: Int
    let albumCount: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
    
    static func == (lhs: Genre, rhs: Genre) -> Bool {
        lhs.value == rhs.value
    }
}
