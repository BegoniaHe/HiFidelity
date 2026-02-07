//
//  ArtworkCache+Public.swift
//  HiFidelity
//
//  Created by Varun Rathod on 03/11/25.
//

import Foundation
import AppKit

extension ArtworkCache {

    // MARK: - Public API - Async Artwork Loading

    /// Get artwork for a track with fallback chain: album → track → nil
    /// - Parameters:
    ///   - trackId: Track database ID
    ///   - size: Target size in points (automatically handles Retina scaling)
    ///   - completion: Called on main thread with result
    func getArtwork(for trackId: Int64, size: CGFloat = 40, completion: @escaping @Sendable (NSImage?) -> Void) {
        let trackKey = "track_\(trackId)_\(Int(size))" as NSString
        let cache = size <= 200 ? thumbnailCache : fullSizeCache

        // Check appropriate cache first (extremely fast, thread-safe)
        if let cachedImage = cache.object(forKey: trackKey) {
            completion(cachedImage)
            return
        }

        // Thread-safe check if we know this track has no artwork
        let noArtworkKey = "track_\(trackId)" as NSString
        var hasNoArtwork = false
        noArtworkQueue.sync {
            hasNoArtwork = noArtworkSet.contains(noArtworkKey)
        }

        if hasNoArtwork {
            completion(nil)
            return
        }

        // Check if already loading this image
        let requestKey = "track_\(trackId)_\(Int(size))"
        var isInflight = false
        inflightSync {
            isInflight = inflightRequests.contains(requestKey)
            if !isInflight {
                inflightRequests.insert(requestKey)
            }
        }

        if isInflight {
            // Already loading, just wait and check cache again shortly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                if let cached = self?.cache(for: size).object(forKey: trackKey) {
                    completion(cached)
                } else {
                    completion(nil)
                }
            }
            return
        }

        // Load from database on background queue
        dbQueue.async { [weak self] in
            guard let self = self else { return }

            defer {
                _ = self.inflightSync {
                    self.inflightRequests.remove(requestKey)
                }
            }

            // Double-check cache
            if let cachedImage = cache.object(forKey: trackKey) {
                DispatchQueue.main.async {
                    completion(cachedImage)
                }
                return
            }

            // Load and decode artwork
            do {
                guard let result = try self.loadTrackArtworkWithFallback(trackId: trackId) else {
                    // Track exists but has no artwork
                    self.noArtworkQueue.async(flags: .barrier) {
                        self.noArtworkSet.add(noArtworkKey)
                    }
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }

                // Decode and downsample image OFF main thread
                self.decodingQueue.async {
                    guard let image = self.downsampleImage(data: result.data, targetSize: size) else {
                        self.noArtworkQueue.async(flags: .barrier) {
                            self.noArtworkSet.add(noArtworkKey)
                        }
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                        return
                    }

                    // Cache the downsampled image
                    let cost = self.calculateImageCost(image)
                    cache.setObject(image, forKey: trackKey, cost: cost)

                    // OPTIMIZATION: If artwork came from album, also cache under album key
                    if let albumId = result.albumId {
                        let albumKey = "album_\(albumId)_\(Int(size))" as NSString
                        cache.setObject(image, forKey: albumKey, cost: cost)
                    }

                    // Return on main thread
                    DispatchQueue.main.async {
                        completion(image)
                    }
                }
            } catch {
                Logger.warning("Failed to load artwork for track \(trackId): \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    /// Get artwork for an album
    /// - Parameters:
    ///   - albumId: Album database ID
    ///   - size: Target size in points
    ///   - completion: Called on main thread with result
    func getAlbumArtwork(for albumId: Int64, size: CGFloat = 160, completion: @escaping @Sendable (NSImage?) -> Void) {
        loadArtwork(
            entityType: ArtworkCache.EntityType.album,
            entityId: albumId,
            size: size,
            completion: completion
        )
    }

    /// Get artwork for an artist
    /// - Parameters:
    ///   - artistId: Artist database ID
    ///   - size: Target size in points
    ///   - completion: Called on main thread with result
    func getArtistArtwork(for artistId: Int64, size: CGFloat = 160, completion: @escaping @Sendable (NSImage?) -> Void) {
        loadArtwork(
            entityType: ArtworkCache.EntityType.artist,
            entityId: artistId,
            size: size,
            completion: completion
        )
    }

    // MARK: - Public API - Synchronous Cache Access

    /// Get cached artwork for track (returns immediately, nil if not cached)
    func getCachedArtwork(for trackId: Int64, size: CGFloat = 40) -> NSImage? {
        getCachedImage(entityType: ArtworkCache.EntityType.track, entityId: trackId, size: size)
    }

    /// Get cached artwork for album (returns immediately, nil if not cached)
    func getCachedAlbumArtwork(for albumId: Int64, size: CGFloat = 160) -> NSImage? {
        getCachedImage(entityType: ArtworkCache.EntityType.album, entityId: albumId, size: size)
    }

    /// Get cached artwork for artist (returns immediately, nil if not cached)
    func getCachedArtistArtwork(for artistId: Int64, size: CGFloat = 160) -> NSImage? {
        getCachedImage(entityType: ArtworkCache.EntityType.artist, entityId: artistId, size: size)
    }

    // MARK: - Public API - Preloading

    /// Preload artwork for visible tracks (call before scrolling into view)
    /// - Parameters:
    ///   - trackIds: Track IDs to preload
    ///   - size: Target size
    ///   - maxConcurrent: Limit to prevent system overload (default: 10)
    func preloadArtwork(for trackIds: [Int64], size: CGFloat = 40, maxConcurrent: Int = 10) {
        preloadImages(entityType: ArtworkCache.EntityType.track, entityIds: trackIds, size: size, maxConcurrent: maxConcurrent)
    }

    /// Preload artwork for albums (call before scrolling into view)
    func preloadAlbumArtwork(for albumIds: [Int64], size: CGFloat = 160, maxConcurrent: Int = 10) {
        preloadImages(entityType: ArtworkCache.EntityType.album, entityIds: albumIds, size: size, maxConcurrent: maxConcurrent)
    }

    // MARK: - Public API - Cache Invalidation

    /// Invalidate track artwork (call when artwork updated)
    func invalidate(trackId: Int64) {
        invalidateCache(entityType: ArtworkCache.EntityType.track, entityId: trackId)
    }

    /// Invalidate album artwork (call when artwork updated)
    func invalidateAlbum(albumId: Int64) {
        invalidateCache(entityType: ArtworkCache.EntityType.album, entityId: albumId)
    }

    /// Invalidate artist artwork (call when artwork updated)
    func invalidateArtist(artistId: Int64) {
        invalidateCache(entityType: ArtworkCache.EntityType.artist, entityId: artistId)
    }

    /// Clear all cached artwork
    func clearAll() {
        thumbnailCache.removeAllObjects()
        fullSizeCache.removeAllObjects()

        noArtworkQueue.async(flags: .barrier) {
            self.noArtworkSet.removeAllObjects()
        }

        inflightSync {
            inflightRequests.removeAll()
        }

        Logger.info("Cleared all artwork cache")
    }
}
