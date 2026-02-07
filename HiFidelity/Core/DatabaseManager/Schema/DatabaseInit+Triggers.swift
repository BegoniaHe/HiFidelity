//
//  DatabaseInit+Triggers.swift
//  HiFidelity
//
//  Created by Varun Rathod on 26/10/25.
//

import Foundation
import GRDB

extension DatabaseManager {

    // MARK: - Database Triggers

    /// Create statistics update triggers for albums, artists, and genres
    /// These triggers automatically update track counts and other statistics when tracks are added, removed, or modified
    nonisolated static func createStatisticsUpdateTriggers(in db: Database) throws {
        try createAlbumStatisticsUpdateTriggers(in: db)
        try createArtistStatisticsUpdateTriggers(in: db)
        try createGenreStatisticsUpdateTriggers(in: db)
        Logger.info("Created statistics update triggers")
    }

    nonisolated private static func createAlbumStatisticsUpdateTriggers(in db: Database) throws {
        // Trigger: Update album statistics when track is deleted
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS update_album_stats_on_delete
            AFTER DELETE ON tracks
            FOR EACH ROW
            WHEN OLD.album_id IS NOT NULL
            BEGIN
                UPDATE albums
                SET track_count = (
                        SELECT COUNT(*) FROM tracks WHERE album_id = OLD.album_id
                    ),
                    total_duration = (
                        SELECT COALESCE(SUM(duration), 0) FROM tracks WHERE album_id = OLD.album_id
                    )
                WHERE id = OLD.album_id;
            END;
        """)

        // Trigger: Update album statistics when track is inserted
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS update_album_stats_on_insert
            AFTER INSERT ON tracks
            FOR EACH ROW
            WHEN NEW.album_id IS NOT NULL
            BEGIN
                UPDATE albums
                SET track_count = (
                        SELECT COUNT(*) FROM tracks WHERE album_id = NEW.album_id
                    ),
                    total_duration = (
                        SELECT COALESCE(SUM(duration), 0) FROM tracks WHERE album_id = NEW.album_id
                    )
                WHERE id = NEW.album_id;
            END;
        """)

        // Trigger: Update album statistics when track's album changes
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS update_album_stats_on_update
            AFTER UPDATE OF album_id, duration ON tracks
            FOR EACH ROW
            WHEN OLD.album_id IS NOT NEW.album_id OR OLD.duration != NEW.duration
            BEGIN
                -- Update old album statistics (if it exists)
                UPDATE albums
                SET track_count = (
                        SELECT COUNT(*) FROM tracks WHERE album_id = OLD.album_id
                    ),
                    total_duration = (
                        SELECT COALESCE(SUM(duration), 0) FROM tracks WHERE album_id = OLD.album_id
                    )
                WHERE id = OLD.album_id AND OLD.album_id IS NOT NULL;

                -- Update new album statistics (if it exists)
                UPDATE albums
                SET track_count = (
                        SELECT COUNT(*) FROM tracks WHERE album_id = NEW.album_id
                    ),
                    total_duration = (
                        SELECT COALESCE(SUM(duration), 0) FROM tracks WHERE album_id = NEW.album_id
                    )
                WHERE id = NEW.album_id AND NEW.album_id IS NOT NULL;
            END;
        """)
    }

    nonisolated private static func createArtistStatisticsUpdateTriggers(in db: Database) throws {
        // Trigger: Update artist statistics when track is deleted
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS update_artist_stats_on_delete
            AFTER DELETE ON tracks
            FOR EACH ROW
            WHEN OLD.artist_id IS NOT NULL
            BEGIN
                UPDATE artists
                SET track_count = (
                        SELECT COUNT(*) FROM tracks WHERE artist_id = OLD.artist_id
                    ),
                    album_count = (
                        SELECT COUNT(DISTINCT album_id) FROM tracks
                        WHERE artist_id = OLD.artist_id AND album_id IS NOT NULL
                    )
                WHERE id = OLD.artist_id;
            END;
        """)

        // Trigger: Update artist statistics when track is inserted
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS update_artist_stats_on_insert
            AFTER INSERT ON tracks
            FOR EACH ROW
            WHEN NEW.artist_id IS NOT NULL
            BEGIN
                UPDATE artists
                SET track_count = (
                        SELECT COUNT(*) FROM tracks WHERE artist_id = NEW.artist_id
                    ),
                    album_count = (
                        SELECT COUNT(DISTINCT album_id) FROM tracks
                        WHERE artist_id = NEW.artist_id AND album_id IS NOT NULL
                    )
                WHERE id = NEW.artist_id;
            END;
        """)

        // Trigger: Update artist statistics when track's artist changes
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS update_artist_stats_on_update
            AFTER UPDATE OF artist_id, album_id ON tracks
            FOR EACH ROW
            WHEN OLD.artist_id IS NOT NEW.artist_id
            BEGIN
                -- Update old artist statistics (if it exists)
                UPDATE artists
                SET track_count = (
                        SELECT COUNT(*) FROM tracks WHERE artist_id = OLD.artist_id
                    ),
                    album_count = (
                        SELECT COUNT(DISTINCT album_id) FROM tracks
                        WHERE artist_id = OLD.artist_id AND album_id IS NOT NULL
                    )
                WHERE id = OLD.artist_id AND OLD.artist_id IS NOT NULL;

                -- Update new artist statistics (if it exists)
                UPDATE artists
                SET track_count = (
                        SELECT COUNT(*) FROM tracks WHERE artist_id = NEW.artist_id
                    ),
                    album_count = (
                        SELECT COUNT(DISTINCT album_id) FROM tracks
                        WHERE artist_id = NEW.artist_id AND album_id IS NOT NULL
                    )
                WHERE id = NEW.artist_id AND NEW.artist_id IS NOT NULL;
            END;
        """)
    }

    nonisolated private static func createGenreStatisticsUpdateTriggers(in db: Database) throws {
        // Trigger: Update genre statistics when track is deleted
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS update_genre_stats_on_delete
            AFTER DELETE ON tracks
            FOR EACH ROW
            WHEN OLD.genre_id IS NOT NULL
            BEGIN
                UPDATE genres
                SET track_count = (
                        SELECT COUNT(*) FROM tracks WHERE genre_id = OLD.genre_id
                    )
                WHERE id = OLD.genre_id;
            END;
        """)

        // Trigger: Update genre statistics when track is inserted
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS update_genre_stats_on_insert
            AFTER INSERT ON tracks
            FOR EACH ROW
            WHEN NEW.genre_id IS NOT NULL
            BEGIN
                UPDATE genres
                SET track_count = (
                        SELECT COUNT(*) FROM tracks WHERE genre_id = NEW.genre_id
                    )
                WHERE id = NEW.genre_id;
            END;
        """)

        // Trigger: Update genre statistics when track's genre changes
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS update_genre_stats_on_update
            AFTER UPDATE OF genre_id ON tracks
            FOR EACH ROW
            WHEN OLD.genre_id IS NOT NEW.genre_id
            BEGIN
                -- Update old genre statistics (if it exists)
                UPDATE genres
                SET track_count = (
                        SELECT COUNT(*) FROM tracks WHERE genre_id = OLD.genre_id
                    )
                WHERE id = OLD.genre_id AND OLD.genre_id IS NOT NULL;

                -- Update new genre statistics (if it exists)
                UPDATE genres
                SET track_count = (
                        SELECT COUNT(*) FROM tracks WHERE genre_id = NEW.genre_id
                    )
                WHERE id = NEW.genre_id AND NEW.genre_id IS NOT NULL;
            END;
        """)
    }

    /// Create triggers to automatically delete orphaned albums, artists, and genres
    /// These triggers fire after track deletion and clean up entities with no remaining tracks
    nonisolated static func createOrphanCleanupTriggers(in db: Database) throws {
        // Trigger: Delete album if its last track is deleted
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS cleanup_orphaned_albums
            AFTER DELETE ON tracks
            FOR EACH ROW
            WHEN OLD.album_id IS NOT NULL
            BEGIN
                DELETE FROM albums
                WHERE id = OLD.album_id
                AND NOT EXISTS (
                    SELECT 1 FROM tracks WHERE album_id = OLD.album_id
                );
            END;
        """)

        // Trigger: Delete artist if its last track is deleted
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS cleanup_orphaned_artists
            AFTER DELETE ON tracks
            FOR EACH ROW
            WHEN OLD.artist_id IS NOT NULL
            BEGIN
                DELETE FROM artists
                WHERE id = OLD.artist_id
                AND NOT EXISTS (
                    SELECT 1 FROM tracks WHERE artist_id = OLD.artist_id
                );
            END;
        """)

        // Trigger: Delete genre if its last track is deleted
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS cleanup_orphaned_genres
            AFTER DELETE ON tracks
            FOR EACH ROW
            WHEN OLD.genre_id IS NOT NULL
            BEGIN
                DELETE FROM genres
                WHERE id = OLD.genre_id
                AND NOT EXISTS (
                    SELECT 1 FROM tracks WHERE genre_id = OLD.genre_id
                );
            END;
        """)

        Logger.info("Created automatic orphan cleanup triggers")
    }
}
