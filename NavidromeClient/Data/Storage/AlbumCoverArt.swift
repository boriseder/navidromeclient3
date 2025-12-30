//
//  AlbumCoverArt.swift
//  NavidromeClient
//
//  Multi-size image container with HIGH-QUALITY scaling
//  Optimized for Retina displays with proper interpolation
//

import UIKit

@MainActor
class AlbumCoverArt {
    private let baseImage: UIImage
    private let baseSize: Int
    private var scaledVariants: [Int: UIImage] = [:]
    private let maxVariants = 3
    
    init(image: UIImage, size: Int) {
        self.baseImage = image
        self.baseSize = size
        AppLogger.general.debug("AlbumCoverArt initialized with size: \(size)px")
    }
    
    // Get image for requested size
    // Returns nil if only smaller images available (triggers network request)
    // Downscales if larger image available (maintains quality)
    func getImage(for requestedSize: Int) -> UIImage? {
        // Exact match for base size
        if requestedSize == baseSize {
            return baseImage
        }
        
        // Return cached variant if available
        if let cached = scaledVariants[requestedSize] {
            return cached
        }
        
        // Find available sizes (base + variants)
        let availableSizes = getSizes().sorted(by: >)
        
        // Strategy: Only downscale from larger images
        // If only smaller images exist, return nil to trigger network request
        if let largerSize = availableSizes.first(where: { $0 >= requestedSize }) {
            let sourceImage: UIImage
            
            if largerSize == baseSize {
                sourceImage = baseImage
            } else if let variant = scaledVariants[largerSize] {
                sourceImage = variant
            } else {
                // Should not happen, but fallback to base
                AppLogger.general.warn("AlbumCoverArt: Inconsistent state - size \(largerSize) in list but not available")
                sourceImage = baseImage
            }
            
            // HIGH-QUALITY downscale synchronously for immediate display
            let scaled = scaleImageHighQuality(sourceImage, to: requestedSize)
            
            // Cache the downscaled variant
            Task {
                await cacheVariant(scaled, size: requestedSize)
            }
            
            AppLogger.general.debug("AlbumCoverArt: Downscaled \(largerSize)px -> \(requestedSize)px (HQ)")
            return scaled
        }
        
        // Only smaller images available - return nil to trigger network request
        AppLogger.general.debug("AlbumCoverArt: No larger image available for \(requestedSize)px (have: \(baseSize)px), returning nil to trigger network request")
        return nil
    }
    
    // Preload a specific size asynchronously
    func preloadSize(_ requestedSize: Int) async {
        guard requestedSize != baseSize else { return }
        guard scaledVariants[requestedSize] == nil else { return }
        
        // Only preload downscaled versions
        guard baseSize >= requestedSize else {
            AppLogger.general.debug("AlbumCoverArt: Skipping preload of \(requestedSize)px (base is only \(baseSize)px)")
            return
        }
        
        let scaled = await scaleImageAsync(baseImage, to: requestedSize)
        await cacheVariant(scaled, size: requestedSize)
        
        AppLogger.general.debug("AlbumCoverArt: Preloaded size \(requestedSize)px")
    }
    
    private func cacheVariant(_ image: UIImage, size: Int) async {
        await MainActor.run {
            // Limit cached variants to prevent memory growth
            if scaledVariants.count >= maxVariants {
                // Remove smallest variant (least useful)
                if let smallestKey = scaledVariants.keys.sorted().first {
                    scaledVariants.removeValue(forKey: smallestKey)
                    AppLogger.general.debug("AlbumCoverArt: Evicted size \(smallestKey)px (cache full)")
                }
            }
            
            scaledVariants[size] = image
        }
    }
    
    // IMPROVED: High-quality image scaling for Retina displays
    private func scaleImageHighQuality(_ image: UIImage, to size: Int) -> UIImage {
        let targetSize = CGSize(width: size, height: size)
        
        // Configure high-quality rendering
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // Important: 1x scale for pixel-perfect rendering
        format.preferredRange = .standard
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        return renderer.image { context in
            // Enable high-quality interpolation
            context.cgContext.interpolationQuality = .high
            
            // Optional: Anti-aliasing for smoother edges
            context.cgContext.setShouldAntialias(true)
            context.cgContext.setAllowsAntialiasing(true)
            
            // Draw with high quality
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    // Synchronous version for immediate display (backwards compatibility)
    private func scaleImageSync(_ image: UIImage, to size: Int) -> UIImage {
        return scaleImageHighQuality(image, to: size)
    }
    
    // Async version for background processing
    private func scaleImageAsync(_ image: UIImage, to size: Int) async -> UIImage {
        await Task.detached(priority: .userInitiated) {
            await MainActor.run {
                self.scaleImageHighQuality(image, to: size)
            }
        }.value
    }
    
    var memoryFootprint: Int {
        // Calculate accurate memory usage based on pixel dimensions
        let scale = baseImage.scale
        let basePixelWidth = baseImage.size.width * scale
        let basePixelHeight = baseImage.size.height * scale
        let baseMemory = Int(basePixelWidth * basePixelHeight * 4) // RGBA = 4 bytes per pixel
        
        let variantMemory = scaledVariants.values.reduce(0) { total, image in
            let variantScale = image.scale
            let pixelWidth = image.size.width * variantScale
            let pixelHeight = image.size.height * variantScale
            return total + Int(pixelWidth * pixelHeight * 4)
        }
        
        return baseMemory + variantMemory
    }
    
    func hasSize(_ size: Int) -> Bool {
        return size == baseSize || scaledVariants[size] != nil
    }
    
    func getSizes() -> [Int] {
        return ([baseSize] + Array(scaledVariants.keys)).sorted()
    }
    
    // Get diagnostic info
    func getInfo() -> String {
        let sizes = getSizes().map { "\($0)px" }.joined(separator: ", ")
        let quality = baseImage.cgImage?.bitsPerPixel ?? 0
        return """
        Base: \(baseSize)px, Variants: \(scaledVariants.count)
        Available: [\(sizes)]
        Quality: \(quality) bits/pixel
        """
    }
}
