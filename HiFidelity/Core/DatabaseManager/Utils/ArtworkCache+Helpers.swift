//
//  ArtworkCache+Helpers.swift
//  HiFidelity
//
//  Created by Varun Rathod on 03/11/25.
//

import AppKit
import Foundation

extension ArtworkCache {
    // MARK: - Private Generic Helpers

    /// Generic artwork loading for any entity type
    func loadArtwork(
        entityType: EntityType,
        entityId: Int64,
        size: CGFloat,
        completion: @escaping @Sendable (NSImage?) -> Void
    ) {
        let key = cacheKey(entityType: entityType, entityId: entityId, size: size)
        let cache = cache(for: size)

        // Fast path: Check cache first
        if let cachedImage = cache.object(forKey: key) {
            completion(cachedImage)
            return
        }

        // Check if known to have no artwork
        if isKnownNoArtwork(entityType: entityType, entityId: entityId) {
            completion(nil)
            return
        }

        // Check if already loading (prevent duplicate requests)
        let requestKey = requestKey(entityType: entityType, entityId: entityId, size: size)
        if isInflightRequest(requestKey) {
            // Wait briefly and check cache again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                completion(self?.cache(for: size).object(forKey: key))
            }
            return
        }

        // Mark as in-flight
        markInflightRequest(requestKey, inflight: true)

        // Load from database on background queue
        dbQueue.async { [weak self] in
            guard let self = self else { return }

            defer {
                self.markInflightRequest(requestKey, inflight: false)
            }

            // Double-check cache
            let cachedImage = cache.object(forKey: key)
            if cachedImage != nil {
                DispatchQueue.main.async { [cachedImage] in
                    completion(cachedImage)
                }
                return
            }

            // Load artwork data from database
            self.loadArtworkData(entityType: entityType, entityId: entityId) { result in
                guard let artworkData = result else {
                    self.markNoArtwork(entityType: entityType, entityId: entityId)
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }

                // Decode and downsample OFF main thread
                self.decodingQueue.async {
                    guard let image = self.downsampleImage(data: artworkData, targetSize: size) else {
                        self.markNoArtwork(entityType: entityType, entityId: entityId)
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                        return
                    }

                    // Cache the image
                    let cost = self.calculateImageCost(image)
                    cache.setObject(image, forKey: key, cost: cost)

                    DispatchQueue.main.async {
                        completion(image)
                    }
                }
            }
        }
    }

    /// Get cached image synchronously
    func getCachedImage(entityType: EntityType, entityId: Int64, size: CGFloat) -> NSImage? {
        let key = cacheKey(entityType: entityType, entityId: entityId, size: size)
        let cache = cache(for: size)
        return cache.object(forKey: key)
    }

    /// Preload multiple images
    func preloadImages(
        entityType: EntityType,
        entityIds: [Int64],
        size: CGFloat,
        maxConcurrent: Int
    ) {
        let uncached = entityIds.filter { entityId in
            getCachedImage(entityType: entityType, entityId: entityId, size: size) == nil &&
            !isKnownNoArtwork(entityType: entityType, entityId: entityId)
        }

        let limited = Array(uncached.prefix(maxConcurrent))

        for entityId in limited {
            loadArtwork(entityType: entityType, entityId: entityId, size: size) { _ in }
        }
    }

    /// Invalidate cached artwork for an entity
    func invalidateCache(entityType: EntityType, entityId: Int64) {
        let standardSizes: [Int] = [40, 56, 140, 160, 200, 300]

        for size in standardSizes {
            let key = cacheKey(entityType: entityType, entityId: entityId, size: CGFloat(size))
            thumbnailCache.removeObject(forKey: key)
            fullSizeCache.removeObject(forKey: key)
        }

        let noArtworkKey = noArtworkKey(entityType: entityType, entityId: entityId)
        noArtworkQueue.async(flags: .barrier) {
            self.noArtworkSet.remove(noArtworkKey)
        }
    }

    // MARK: - Private Helper Methods

    /// Get the appropriate cache for a given size
    func cache(for size: CGFloat) -> NSCache<NSString, NSImage> {
        size <= 200 ? thumbnailCache : fullSizeCache
    }

    /// Generate cache key for an entity
    func cacheKey(entityType: EntityType, entityId: Int64, size: CGFloat) -> NSString {
        "\(entityType.rawValue)_\(entityId)_\(Int(size))" as NSString
    }

    /// Generate no-artwork key for an entity
    func noArtworkKey(entityType: EntityType, entityId: Int64) -> NSString {
        "\(entityType.rawValue)_\(entityId)" as NSString
    }

    /// Generate request key for in-flight tracking
    func requestKey(entityType: EntityType, entityId: Int64, size: CGFloat) -> String {
        "\(entityType.rawValue)_\(entityId)_\(Int(size))"
    }

    /// Check if entity is known to have no artwork
    func isKnownNoArtwork(entityType: EntityType, entityId: Int64) -> Bool {
        let key = noArtworkKey(entityType: entityType, entityId: entityId)
        return noArtworkQueue.sync {
            noArtworkSet.contains(key)
        }
    }

    /// Mark entity as having no artwork
    func markNoArtwork(entityType: EntityType, entityId: Int64) {
        let key = noArtworkKey(entityType: entityType, entityId: entityId)
        noArtworkQueue.async(flags: .barrier) {
            self.noArtworkSet.add(key)
        }
    }

    /// Check if request is in-flight
    func isInflightRequest(_ requestKey: String) -> Bool {
        inflightSync {
            let isInflight = inflightRequests.contains(requestKey)
            if !isInflight {
                inflightRequests.insert(requestKey)
            }
            return isInflight
        }
    }

    /// Mark request as in-flight or complete
    func markInflightRequest(_ requestKey: String, inflight: Bool) {
        inflightSync {
            if inflight {
                inflightRequests.insert(requestKey)
            } else {
                inflightRequests.remove(requestKey)
            }
        }
    }
}
