//
//  AlbumCoverArt.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Non-isolated scaling logic enables true background processing
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
    
    func getImage(for requestedSize: Int) -> UIImage? {
        if requestedSize == baseSize { return baseImage }
        if let cached = scaledVariants[requestedSize] { return cached }
        
        let availableSizes = getSizes().sorted(by: >)
        
        if let largerSize = availableSizes.first(where: { $0 >= requestedSize }) {
            let sourceImage: UIImage = (largerSize == baseSize) ? baseImage : (scaledVariants[largerSize] ?? baseImage)
            
            // Perform high-quality synchronous scaling (on MainActor but uses nonisolated helper)
            // Note: For immediate display, sync is often required to prevent flickering.
            // For purely async scaling, use preloadSize.
            let scaled = scaleImageHighQuality(sourceImage, to: requestedSize)
            
            Task { await cacheVariant(scaled, size: requestedSize) }
            return scaled
        }
        
        return nil
    }
    
    func preloadSize(_ requestedSize: Int) async {
        guard requestedSize != baseSize else { return }
        guard scaledVariants[requestedSize] == nil else { return }
        guard baseSize >= requestedSize else { return }
        
        // Use detached task for heavy lifting
        let source = baseImage
        let scaled = await Task.detached {
            return self.scaleImageHighQuality(source, to: requestedSize)
        }.value
        
        await cacheVariant(scaled, size: requestedSize)
    }
    
    private func cacheVariant(_ image: UIImage, size: Int) {
        if scaledVariants.count >= maxVariants {
            if let smallestKey = scaledVariants.keys.sorted().first {
                scaledVariants.removeValue(forKey: smallestKey)
            }
        }
        scaledVariants[size] = image
    }
    
    // Swift 6: Marked nonisolated. UIGraphicsImageRenderer is thread-safe.
    // This allows execution on background threads.
    private nonisolated func scaleImageHighQuality(_ image: UIImage, to size: Int) -> UIImage {
        let targetSize = CGSize(width: size, height: size)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.preferredRange = .standard
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        return renderer.image { context in
            context.cgContext.interpolationQuality = .high
            context.cgContext.setShouldAntialias(true)
            context.cgContext.setAllowsAntialiasing(true)
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    var memoryFootprint: Int {
        // Approximate memory usage
        let scale = baseImage.scale
        let baseMem = Int(baseImage.size.width * scale * baseImage.size.height * scale * 4)
        
        let variantMem = scaledVariants.values.reduce(0) { total, img in
            let vScale = img.scale
            return total + Int(img.size.width * vScale * img.size.height * vScale * 4)
        }
        
        return baseMem + variantMem
    }
    
    func getSizes() -> [Int] {
        return ([baseSize] + Array(scaledVariants.keys)).sorted()
    }
}
