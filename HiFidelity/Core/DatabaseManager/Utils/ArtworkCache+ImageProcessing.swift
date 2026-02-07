//
//  ArtworkCache+ImageProcessing.swift
//  HiFidelity
//
//  Created by Varun Rathod on 03/11/25.
//

import Foundation
import AppKit

extension ArtworkCache {

    // MARK: - Private Image Processing

    /// Downsample image to target size for memory efficiency
    /// Uses high-quality Lanczos resampling for best visual quality
    private func downsampleImage(data: Data, targetSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        // Get original image dimensions
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as? CGFloat,
              let pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as? CGFloat else {
            // Fallback to regular decoding if we can't get properties
            return NSImage(data: data)
        }

        // Calculate actual scale needed (use 2x for Retina displays)
        let scale: CGFloat = 2.0
        let maxDimension = max(pixelWidth, pixelHeight)
        let targetPixelSize = targetSize * scale

        // Only downsample if source is significantly larger
        if maxDimension <= targetPixelSize * 1.5 {
            // Image is already small enough, just decode it
            return NSImage(data: data)
        }

        // Create thumbnail with downsampling
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize,
            kCGImageSourceShouldCache: false  // We're doing our own caching
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            // Fallback to regular decoding
            return NSImage(data: data)
        }

        // Convert CGImage to NSImage
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let image = NSImage(cgImage: cgImage, size: size)

        return image
    }

    /// Calculate memory cost for an image
    private func calculateImageCost(_ image: NSImage) -> Int {
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        // 4 bytes per pixel (RGBA)
        return width * height * 4
    }
}
