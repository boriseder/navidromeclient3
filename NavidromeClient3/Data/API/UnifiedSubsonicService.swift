//
//  UnifiedSubsonicService.swift
//  NavidromeClient
//
//  Swift 6: Facade Actor
//

import Foundation
import UIKit

actor UnifiedSubsonicService {
    
    // MARK: - Private Specialists (Actors)
    private let connectionService: ConnectionService
    private let contentService: ContentService
    private let mediaService: MediaService
    private let discoveryService: DiscoveryService
    private let favoritesService: FavoritesService

    // MARK: - Initialization
    init(baseURL: URL, username: String, password: String) {
        // 1. Create Base Actor
        let conn = ConnectionService(baseURL: baseURL, username: username, password: password)
        self.connectionService = conn
        
        // 2. Inject into Specialists
        self.contentService = ContentService(connectionService: conn)
        self.mediaService = MediaService(connectionService: conn)
        self.discoveryService = DiscoveryService(connectionService: conn)
        self.favoritesService = FavoritesService(connectionService: conn)
        
        AppLogger.general.info("UnifiedSubsonicService (Actor) initialized")
    }
    
    // MARK: - Delegated Operations
    
    // All public methods are implicitly async because this is an actor
    
    func ping() async -> Bool {
        await connectionService.ping()
    }
    
    func getAllAlbums(size: Int, offset: Int) async throws -> [Album] {
        try await contentService.getAllAlbums(size: size, offset: offset)
    }
    
    func getCoverArt(for id: String, size: Int) async -> UIImage? {
        await mediaService.getCoverArt(for: id, size: size)
    }
    
    // ... [Delegate all other methods similarly] ...
}
