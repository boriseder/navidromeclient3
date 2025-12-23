import SwiftUI

// MARK: - Genres
struct GenresContainer: Codable {
    let genres: GenreList?
}

struct GenreList: Codable {
    let genre: [Genre]?
}

struct Genre: Identifiable, Hashable, Codable {
    var id: String { value }
    let value: String
    let songCount: Int
    let albumCount: Int
    
    // Sagt Swift: "value" ist der eindeutige Identifier
    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
    
    // Sagt Swift: Zwei Genres sind gleich wenn value gleich ist
    static func == (lhs: Genre, rhs: Genre) -> Bool {
        return lhs.value == rhs.value
    }
}

