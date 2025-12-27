import Foundation
import UIKit

actor MediaService {
    private let connectionService: ConnectionService
    private let session: URLSession
    
    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        self.session = URLSession(configuration: config)
    }
    
    func getCoverArt(for coverId: String, size: Int) async -> UIImage? {
        // FIX: await connectionService
        guard let url = await connectionService.buildURL(
            endpoint: "getCoverArt",
            params: ["id": coverId, "size": "\(size)"]
        ) else { return nil }
        
        do {
            let (data, _) = try await session.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            
            await PersistentImageCache.shared.store(image, for: coverId, size: size)
            return image
        } catch {
            return nil
        }
    }
    
    func streamURL(for songId: String) async -> URL? {
        // FIX: await connectionService
        await connectionService.buildURL(endpoint: "stream", params: ["id": songId])
    }
    
    func downloadURL(for songId: String, maxBitRate: Int? = nil) async -> URL? {
        var params = ["id": songId]
        if let rate = maxBitRate { params["maxBitRate"] = "\(rate)" }
        // FIX: await connectionService
        return await connectionService.buildURL(endpoint: "download", params: params)
    }
}
