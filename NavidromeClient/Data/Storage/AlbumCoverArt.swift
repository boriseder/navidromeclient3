//
//  AlbumCoverArt.swift
//  NavidromeClient
//
//  REFACTORED: Step 3 — removed @MainActor
//  UIGraphicsImageRenderer is thread-safe. No UI state here.
//  Safe to call from any actor including ImageCacheActor.
//

import UIKit

class AlbumCoverArt {
    private let baseImage: UIImage
    private let baseSize: Int
    private var scaledVariants: [Int: UIImage] = [:]
    private let maxVariants = 3

    init(image: UIImage, size: Int) {
        self.baseImage = image
        self.baseSize = size
    }

    func getImage(for requestedSize: Int) -> UIImage? {
        if requestedSize == baseSize { return baseImage }
        if let cached = scaledVariants[requestedSize] { return cached }

        let availableSizes = getSizes().sorted(by: >)

        if let largerSize = availableSizes.first(where: { $0 >= requestedSize }) {
            let sourceImage = (largerSize == baseSize)
                ? baseImage
                : (scaledVariants[largerSize] ?? baseImage)

            let scaled = scaleImageHighQuality(sourceImage, to: requestedSize)
            cacheVariant(scaled, size: requestedSize)
            return scaled
        }

        return nil
    }

    func preloadSize(_ requestedSize: Int) async {
        guard requestedSize != baseSize else { return }
        guard scaledVariants[requestedSize] == nil else { return }
        guard baseSize >= requestedSize else { return }

        let source = baseImage
        let targetSize = requestedSize
        // Capture the nonisolated function as a value to avoid sending `self`
        let scaler = scaleImageHighQuality(_:to:)
        
        // EDB to check
        /*
        let scaled = await Task.detached {
            scaler(source, targetSize)
        }.value
        */
        // ---
        
        let scaled = scaler(source, targetSize)
        
        cacheVariant(scaled, size: requestedSize)
    }
    
    private func cacheVariant(_ image: UIImage, size: Int) {
        if scaledVariants.count >= maxVariants,
           let smallest = scaledVariants.keys.sorted().first {
            scaledVariants.removeValue(forKey: smallest)
        }
        scaledVariants[size] = image
    }

    // nonisolated: UIGraphicsImageRenderer is documented thread-safe
    nonisolated func scaleImageHighQuality(_ image: UIImage, to size: Int) -> UIImage {
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
        let scale = baseImage.scale
        let baseMem = Int(baseImage.size.width * scale * baseImage.size.height * scale * 4)
        let variantMem = scaledVariants.values.reduce(0) { total, img in
            let s = img.scale
            return total + Int(img.size.width * s * img.size.height * s * 4)
        }
        return baseMem + variantMem
    }

    func getSizes() -> [Int] {
        ([baseSize] + Array(scaledVariants.keys)).sorted()
    }
}
