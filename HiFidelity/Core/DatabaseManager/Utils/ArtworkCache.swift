//
//  ArtworkCache.swift
//  HiFidelity
//
//  Created by Varun Rathod on 03/11/25.
//

import AppKit
import Foundation
import GRDB

// MARK: - Artwork Cache

/// High-performance artwork cache with downsampling, prefetching, and multi-level caching
///
/// Features:
/// - Two-tier memory cache (thumbnails + full-size)
/// - Size-specific downsampling for optimal memory usage
/// - In-flight request deduplication
/// - Fallback chain: album → track → nil
/// - Cross-caching (album artwork shared across tracks)
@MainActor
final class ArtworkCache {
    // MARK: - Singleton

    static let shared = ArtworkCache()

    // MARK: - Properties

    // Two-tier cache system optimized for different use cases
    let thumbnailCache = NSCache<NSString, NSImage>()  // For lists/grids (≤200pt)
    let fullSizeCache = NSCache<NSString, NSImage>()   // For detail views (>200pt)

    // Tracks entities known to have no artwork (avoid repeated DB queries)
    let noArtworkSet = NSMutableSet()
    let noArtworkQueue = DispatchQueue(label: "com.hifidelity.noArtworkSet", attributes: .concurrent)

    // Processing queues
    let decodingQueue = DispatchQueue(label: "com.hifidelity.imageDecoding", qos: .userInitiated, attributes: .concurrent)
    let dbQueue = DispatchQueue(label: "com.hifidelity.artworkCache", qos: .userInitiated)

    // In-flight request tracking (prevent duplicate loads)
    var inflightRequests = Set<String>()
    let inflightQueue = DispatchQueue(label: "com.hifidelity.inflightRequests")
    private let inflightQueueKey = DispatchSpecificKey<Void>()

    // MARK: - Initialization

    private init() {
        let userCacheSizeMB = UserDefaults.standard.object(forKey: "artworkCacheSize") as? Int ?? 500
        configureCacheSize(sizeMB: userCacheSizeMB)
        inflightQueue.setSpecific(key: inflightQueueKey, value: ())
    }

    func inflightSync<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: inflightQueueKey) != nil {
            return work()
        }
        return inflightQueue.sync(execute: work)
    }

    // MARK: - Configuration

    /// Update cache size limits dynamically
    /// - Parameter sizeMB: Total cache size in megabytes (minimum 100 MB)
    func updateCacheSize(sizeMB: Int) {
        let safeSizeMB = max(100, sizeMB)
        UserDefaults.standard.set(safeSizeMB, forKey: "artworkCacheSize")
        configureCacheSize(sizeMB: safeSizeMB)
        Logger.info("Updated artwork cache size to \(safeSizeMB) MB")
    }

    private func configureCacheSize(sizeMB: Int) {
        let totalBytes = sizeMB * 1024 * 1024

        // Split allocation: 40% thumbnails (high volume), 60% full-size (lower volume)
        let thumbnailBytes = Int(Double(totalBytes) * 0.4)
        let fullSizeBytes = Int(Double(totalBytes) * 0.6)

        thumbnailCache.countLimit = sizeMB * 2
        thumbnailCache.totalCostLimit = thumbnailBytes
        thumbnailCache.name = "ArtworkThumbnailCache"

        fullSizeCache.countLimit = sizeMB / 2
        fullSizeCache.totalCostLimit = fullSizeBytes
        fullSizeCache.name = "ArtworkFullSizeCache"
    }

    // MARK: - Private Types

    /// Entity types that can have artwork
    enum EntityType: String {
        case track
        case album
        case artist
    }
}
