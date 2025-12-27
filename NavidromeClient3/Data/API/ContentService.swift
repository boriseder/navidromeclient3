//
//  ContentService.swift
//  NavidromeClient
//
//  Swift 6: Converted to Actor
//

import Foundation

actor ContentService {
    private let connectionService: ConnectionService
    
    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
    }
    
    // MARK: -  ALBUMS API
    
    func getAllAlbums(
        sortBy: AlbumSortType = .alphabetical,
        size: Int = 500,
        offset: Int = 0
    ) async throws -> [Album] {
        let params = [
            "type": sortBy.rawValue,
            "size": "\(size)",
            "offset": "\(offset)"
        ]
        
        let decoded: SubsonicResponse<AlbumListContainer> = try await fetchData(
            endpoint: "getAlbumList2",
            params: params
        )
        return decoded.subsonicResponse.albumList2.album
    }
    
    // ... [Other methods getArtists, getSongs follow same pattern] ...
    
    // MARK: -  CORE FETCH IMPLEMENTATION
    
    private func fetchData<T: Decodable>(
        endpoint: String,
        params: [String: String] = [:]
    ) async throws -> T {
        // Await the actor to get the URL
        guard let url = await connectionService.buildURL(endpoint: endpoint, params: params) else {
            throw SubsonicError.badURL
        }
        
        // Await the actor to perform the network request
        let (data, response) = try await connectionService.getData(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubsonicError.unknown
        }
        
        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(T.self, from: data)
        case 401:
            throw SubsonicError.unauthorized
        case 500...599:
            throw SubsonicError.server(statusCode: httpResponse.statusCode)
        default:
            throw SubsonicError.server(statusCode: httpResponse.statusCode)
        }
    }
}
