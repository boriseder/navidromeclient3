//
//  ImageContext.swift
//  NavidromeClient
//
//  Defines display contexts for images with optimal sizes
//  Each context represents a specific UI use case
//  NOW WITH RETINA SUPPORT for crisp images on all devices
//

import Foundation
import UIKit

enum ImageContext {
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
    
    // NEUE: Custom size mit explizitem Scale
    case custom(displaySize: CGFloat, scale: CGFloat)
    
    /// Base size in points (logical pixels)
    /// Diese Werte repräsentieren die UI-Größe, NICHT die tatsächlichen Pixel
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
    /// Dies berücksichtigt Retina-Displays (2x, 3x)
    var size: Int {
        let scale = self.scale
        let pixelSize = Int(CGFloat(baseSize) * scale)
        
        // Hard cap to prevent unnecessary large requests (Navidrome limit is often ~1500px)
        let maxServerCap = 1600
        
        // Round up to common server sizes for better caching
        let commonSizes = [100, 150, 200, 300, 400, 500, 600, 800, 1000, 1200, 1500]
        
        // Find next larger common size for better quality, but enforce max cap
        if let nextSize = commonSizes.first(where: { $0 >= pixelSize }) {
            return min(nextSize, maxServerCap)
        }
        
        return min(pixelSize, maxServerCap)
    }
    
    /// Display scale factor (1x, 2x, 3x for Retina)
    var scale: CGFloat {
        switch self {
        case .custom(_, let scale):
            return scale
        default:
            return UIScreen.main.scale
        }
    }
    
    /// Display size in points (for SwiftUI layout)
    var displaySize: CGFloat {
        return CGFloat(baseSize)
    }
    
    var isAlbumContext: Bool {
        switch self {
        case .list, .card, .grid, .detail, .hero, .fullscreen, .miniPlayer:
            return true
        case .artistList, .artistCard, .artistHero:
            return false
        case .custom:
            return true // Assume album by default
        }
    }
    
    var isArtistContext: Bool {
        return !isAlbumContext
    }
    
    // MARK: - Factory Methods with Explicit Scale
    
    /// Create context with custom display scale (useful for testing or specific devices)
    static func withScale(_ context: ImageContext, scale: CGFloat) -> ImageContext {
        switch context {
        case .list:
            return .custom(displaySize: 80, scale: scale)
        case .card:
            return .custom(displaySize: DSLayout.cardCoverNoPadding, scale: scale)
        case .grid:
            return .custom(displaySize: 200, scale: scale)
        case .artistList:
            return .custom(displaySize: 50, scale: scale)
        case .artistCard:
            return .custom(displaySize: 150, scale: scale)
        case .artistHero:
            return .custom(displaySize: 240, scale: scale)
        case .detail:
            return .custom(displaySize: 360, scale: scale)
        case .hero:
            return .custom(displaySize: 600, scale: scale)
        case .fullscreen:
            return .custom(displaySize: 1000, scale: scale)
        case .miniPlayer:
            return .custom(displaySize: DSLayout.cardCoverNoPadding, scale: scale)
        case .custom:
            return context
        }
    }
    
    // MARK: - Debugging
    
    var debugDescription: String {
        return """
        ImageContext:
          Type: \(self)
          Display: \(baseSize)pt
          Scale: \(scale)x
          Pixels: \(size)px
        """
    }
}

// MARK: - Size Mapping Reference
/*
 iPhone Display Scale Factors:
 - iPhone SE, 8, 8 Plus: 2x
 - iPhone X, 11, 12, 13, 14, 15: 3x
 - iPad: 2x
 - iPad Pro: 2x
 
 Example Calculations:
 ┌────────────┬─────────┬────────┬────────┬────────────────┐
 │ Context    │ Points  │ 2x     │ 3x     │ Server Request │
 ├────────────┼─────────┼────────┼────────┼────────────────┤
 │ list       │ 80pt    │ 160px  │ 240px  │ 300px          │
 │ card       │ ~100pt  │ 200px  │ 300px  │ 300px          │
 │ grid       │ 200pt   │ 400px  │ 600px  │ 600px          │
 │ detail     │ 360pt   │ 720px  │ 1080px │ 1200px         │
 │ hero       │ 600pt   │ 1200px │ 1800px │ 1800px*        │
 │ fullscreen │ 1000pt  │ 2000px │ 3000px │ 3000px*        │
 └────────────┴─────────┴────────┴────────┴────────────────┘
 
 *Limited by Navidrome's 1500px max - will be downscaled
 */
