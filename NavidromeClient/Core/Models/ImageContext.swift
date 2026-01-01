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

enum ImageContext: Sendable {
    case list, card, grid, detail, hero, fullscreen, miniPlayer
    case artistList, artistCard, artistHero
    case custom(displaySize: CGFloat, scale: CGFloat)
    
    var baseSize: Int {
        switch self {
        case .list: return 80
        case .card, .miniPlayer: return 168
        case .grid: return 200
        case .artistList: return 50
        case .artistCard: return 150
        case .artistHero: return 240
        case .detail: return 360
        case .hero: return 600
        case .fullscreen: return 1000
        case .custom(let displaySize, _): return Int(displaySize)
        }
    }
    
    var scale: CGFloat {
        switch self {
        case .custom(_, let scale): return scale
        default: return 3.0 // FIX: Default to @3x to avoid MainActor dependency
        }
    }
    
    var size: Int {
        let pixelSize = Int(CGFloat(baseSize) * scale)
        let maxServerCap = 1600
        let commonSizes = [100, 150, 200, 300, 400, 500, 600, 800, 1000, 1200, 1500]
        if let nextSize = commonSizes.first(where: { $0 >= pixelSize }) {
            return min(nextSize, maxServerCap)
        }
        return min(pixelSize, maxServerCap)
    }
    
    var displaySize: CGFloat { CGFloat(baseSize) }
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
