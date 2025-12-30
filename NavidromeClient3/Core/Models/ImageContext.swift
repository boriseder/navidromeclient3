//
//  ImageContext.swift
//  NavidromeClient3
//
//  Swift 6: Added UIKit import for UITraitCollection/CGFloat support
//

import Foundation
import UIKit // <--- REQUIRED for UITraitCollection and CGFloat

enum ImageContext: Sendable {
    // Album Display Contexts
    case list
    case card
    case grid
    case detail
    case hero
    case fullscreen
    case miniPlayer
    
    // Artist Display Contexts
    case artistList
    case artistCard
    case artistHero
    
    // Custom size with explicit scale
    case custom(displaySize: CGFloat, scale: CGFloat)
    
    /// Base size in points (logical pixels)
    var baseSize: Int {
        switch self {
        case .list:
            return 80
        case .card, .miniPlayer:
            return Int(DSLayout.cardCoverNoPadding)
        case .grid:
            return 200
        case .artistList:
            return 50
        case .artistCard:
            return 150
        case .artistHero:
            return 240
        case .detail:
            return 360
        case .hero:
            return 600
        case .fullscreen:
            return 1000
        case .custom(let displaySize, _):
            return Int(displaySize)
        }
    }
    
    /// Actual pixel size requested from server (baseSize × scale)
    @MainActor
    var size: Int {
        let scale = self.scale
        let pixelSize = Int(CGFloat(baseSize) * scale)
        let maxServerCap = 1600
        let commonSizes = [100, 150, 200, 300, 400, 500, 600, 800, 1000, 1200, 1500]
        
        if let nextSize = commonSizes.first(where: { $0 >= pixelSize }) {
            return min(nextSize, maxServerCap)
        }
        
        return min(pixelSize, maxServerCap)
    }
    
    /// Display scale factor
    @MainActor
    var scale: CGFloat {
        switch self {
        case .custom(_, let scale):
            return scale
        default:
            return UITraitCollection.current.displayScale
        }
    }
    
    /// Display size in points (for SwiftUI layout)
    var displaySize: CGFloat {
        CGFloat(baseSize)
    }
    
    var isAlbumContext: Bool {
        switch self {
        case .list, .card, .grid, .detail, .hero, .fullscreen, .miniPlayer:
            return true
        case .artistList, .artistCard, .artistHero:
            return false
        case .custom:
            return true
        }
    }
    
    var isArtistContext: Bool {
        !isAlbumContext
    }
    
    // MARK: - Factory Methods
    
    static func withScale(_ context: ImageContext, scale: CGFloat) -> ImageContext {
        switch context {
        case .list: return .custom(displaySize: 80, scale: scale)
        case .card: return .custom(displaySize: DSLayout.cardCoverNoPadding, scale: scale)
        case .grid: return .custom(displaySize: 200, scale: scale)
        case .artistList: return .custom(displaySize: 50, scale: scale)
        case .artistCard: return .custom(displaySize: 150, scale: scale)
        case .artistHero: return .custom(displaySize: 240, scale: scale)
        case .detail: return .custom(displaySize: 360, scale: scale)
        case .hero: return .custom(displaySize: 600, scale: scale)
        case .fullscreen: return .custom(displaySize: 1000, scale: scale)
        case .miniPlayer: return .custom(displaySize: DSLayout.cardCoverNoPadding, scale: scale)
        case .custom(let size, _): return .custom(displaySize: size, scale: scale)
        }
    }
    
    var debugDescription: String {
         return "ImageContext: \(self)"
    }
}
