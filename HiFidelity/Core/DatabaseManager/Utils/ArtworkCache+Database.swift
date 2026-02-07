//
//  ArtworkCache+Database.swift
//  HiFidelity
//
//  Created by Varun Rathod on 03/11/25.
//

import Foundation
import GRDB

extension ArtworkCache {

    // MARK: - Private Database Loading

    /// Load artwork data from database with appropriate fallback
    private func loadArtworkData(
        entityType: EntityType,
        entityId: Int64,
        completion: @escaping (Data?) -> Void
    ) {
        do {
            let data: Data?
            switch entityType {
            case .track:
                data = try loadTrackArtworkWithFallback(trackId: entityId)?.data
            case .album:
                data = try loadAlbumArtworkWithFallback(albumId: entityId)
            case .artist:
                data = try loadArtistArtworkWithFallback(artistId: entityId)
            }
            completion(data)
        } catch {
            Logger.warning("Failed to load artwork for \(entityType) \(entityId): \(error)")
            completion(nil)
        }
    }

    // MARK: - Private Database Fallback Logic

    /// Result type for track artwork (includes album ID for cache optimization)
    private struct TrackArtworkResult {
        let data: Data
        let albumId: Int64?
    }

    /// Load track artwork with fallback chain: album → track → nil
    /// Optimized: Uses DatabaseCache to avoid extra queries when possible
    private func loadTrackArtworkWithFallback(trackId: Int64) throws -> TrackArtworkResult? {
        // Try to get albumId from DatabaseCache first (zero DB queries)
        let cachedAlbumId = DatabaseCache.shared.track(trackId)?.albumId

        return try DatabaseManager.shared.dbQueue.read { db in
            var trackArtwork: Data?
            var albumId: Int64? = cachedAlbumId

            // Load album ID if not cached
            if albumId == nil {
                let row = try Row.fetchOne(db, sql: """
                    SELECT artwork_data, album_id
                    FROM tracks
                    WHERE id = ?
                    """, arguments: [trackId])

                guard let row = row else { return nil }

                trackArtwork = row["artwork_data"]
                albumId = row["album_id"]
            }

            // Prefer album artwork (most common case)
            if let albumId = albumId,
               let row = try Row.fetchOne(db, sql: """
                   SELECT artwork_data
                   FROM albums
                   WHERE id = ?
                   """, arguments: [albumId]),
               let albumArtwork = row["artwork_data"] as Data?,
               !albumArtwork.isEmpty {
                return TrackArtworkResult(data: albumArtwork, albumId: albumId)
            }

            // Load track artwork if we haven't yet
            if trackArtwork == nil {
                let row = try Row.fetchOne(db, sql: """
                    SELECT artwork_data
                    FROM tracks
                    WHERE id = ?
                    """, arguments: [trackId])
                trackArtwork = row?["artwork_data"]
            }

            // Fallback to track-specific artwork
            if let trackArtwork = trackArtwork, !trackArtwork.isEmpty {
                return TrackArtworkResult(data: trackArtwork, albumId: nil)
            }

            return nil
        }
    }

    /// Load album artwork with fallback chain: album → first track → nil
    private func loadAlbumArtworkWithFallback(albumId: Int64) throws -> Data? {
        try DatabaseManager.shared.dbQueue.read { db in
            // Try album's own artwork
            if let row = try Row.fetchOne(db, sql: """
                SELECT artwork_data
                FROM albums
                WHERE id = ?
                """, arguments: [albumId]),
               let albumArtwork = row["artwork_data"] as Data?,
               !albumArtwork.isEmpty {
                return albumArtwork
            }

            // Fallback: Use first track with artwork
            if let row = try Row.fetchOne(db, sql: """
                SELECT artwork_data
                FROM tracks
                WHERE album_id = ? AND artwork_data IS NOT NULL
                LIMIT 1
                """, arguments: [albumId]),
               let trackArtwork = row["artwork_data"] as Data?,
               !trackArtwork.isEmpty {
                return trackArtwork
            }

            return nil
        }
    }

    /// Load artist artwork (no fallback - artists have their own artwork or none)
    private func loadArtistArtworkWithFallback(artistId: Int64) throws -> Data? {
        try DatabaseManager.shared.dbQueue.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT artwork_data
                FROM artists
                WHERE id = ?
                """, arguments: [artistId])

            guard let row = row,
                  let artistArtwork = row["artwork_data"] as Data?,
                  !artistArtwork.isEmpty else {
                return nil
            }

            return artistArtwork
        }
    }
}
