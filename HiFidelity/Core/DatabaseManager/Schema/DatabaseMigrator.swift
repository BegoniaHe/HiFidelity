//
//  DatabaseMigrator.swift
//  HiFidelity
//
//  Created by Varun Rathod on 26/10/25.
//

//
// DatabaseMigrator.swift
//

import Foundation
import GRDB

/// Manages database migrations using GRDB's built-in migration system
struct DatabaseMigrator {
    /// Creates and configures the database migrator with all migrations
    static func setupMigrator() -> GRDB.DatabaseMigrator {
        Logger.info("Setting up database migrator")
        var migrator = GRDB.DatabaseMigrator()

        // MARK: - Initial Schema Migration
        migrator.registerMigration("v1_initial_schema") { db in
            // Check if this is a fresh database by looking for core tables
            let tracksExist = try db.tableExists("tracks")
            let foldersExist = try db.tableExists("folders")

            let tablesExist = tracksExist || foldersExist

            if !tablesExist {
                // Fresh database - create initial schema using static setup methods
                try DatabaseManager.createAllTables(in: db)
            } else {
                // Existing database - this is our baseline
                Logger.info("Existing database detected, marking as v1 baseline")
            }
        }

        // MARK: - Future Migrations

        // v2: Add database triggers for automatic orphan cleanup
        migrator.registerMigration("v2_orphan_cleanup_triggers") { db in
            Logger.info("Creating automatic orphan cleanup triggers...")
            try DatabaseManager.createOrphanCleanupTriggers(in: db)
        }

        // v3: Add FTS5 virtual tables for full-text search
        migrator.registerMigration("v3_fts5_search") { db in
            Logger.info("Creating FTS5 virtual tables...")
            try DatabaseManager.createFTSTables(in: db)
        }

        // v4: Add statistics update triggers for albums, artists, and genres
        migrator.registerMigration("v4_statistics_update_triggers") { db in
            Logger.info("Creating statistics update triggers...")
            try DatabaseManager.createStatisticsUpdateTriggers(in: db)
        }

        // v5: Upgrade FTS5 tables with improved tokenization and BM25 ranking
        migrator.registerMigration("v5_enhanced_fts5") { db in
            try DatabaseManager.upgradeFTSTables(in: db)
        }

        // v6: Add R128 loudness analysis columns
        migrator.registerMigration("v6_r128_loudness") { db in
            Logger.info("Adding R128 integrated loudness column...")
            try db.addColumnIfNotExists(
                table: "tracks",
                column: "r128_integrated_loudness",
                type: .real
            )
            Logger.info("R128 loudness column added successfully")
        }

        // v7: Add remote Jellyfin tracks table with FTS support
        migrator.registerMigration("v7_remote_tracks") { db in
            Logger.info("Creating remote tracks schema...")
            try DatabaseManager.createRemoteTracksTable(in: db)

            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS remote_tracks_fts USING fts5(
                    id UNINDEXED,
                    remote_item_id UNINDEXED,
                    title,
                    artist,
                    album,
                    album_artist,
                    genre,
                    content='remote_tracks',
                    content_rowid='id',
                    tokenize='unicode61 remove_diacritics 2'
                )
            """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS remote_tracks_fts_insert AFTER INSERT ON remote_tracks BEGIN
                    INSERT INTO remote_tracks_fts(rowid, id, remote_item_id, title, artist, album, album_artist, genre)
                    VALUES (new.id, new.id, new.remote_item_id, new.title, new.artist, new.album, new.album_artist, new.genre);
                END;
            """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS remote_tracks_fts_delete AFTER DELETE ON remote_tracks BEGIN
                    DELETE FROM remote_tracks_fts WHERE rowid = old.id;
                END;
            """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS remote_tracks_fts_update AFTER UPDATE ON remote_tracks BEGIN
                    DELETE FROM remote_tracks_fts WHERE rowid = old.id;
                    INSERT INTO remote_tracks_fts(rowid, id, remote_item_id, title, artist, album, album_artist, genre)
                    VALUES (new.id, new.id, new.remote_item_id, new.title, new.artist, new.album, new.album_artist, new.genre);
                END;
            """)

            try db.execute(sql: "INSERT INTO remote_tracks_fts(remote_tracks_fts) VALUES('rebuild')")
            try db.execute(sql: "INSERT INTO remote_tracks_fts(remote_tracks_fts) VALUES('optimize')")

            Logger.info("Remote tracks migration completed")
        }

        // v8: Extend queue persistence to support remote entries
        migrator.registerMigration("v8_queue_remote_support") { db in
            Logger.info("Upgrading queue table for remote support...")

            try db.execute(sql: "ALTER TABLE queue RENAME TO queue_old")

            try db.create(table: "queue") { tableDefinition in
                tableDefinition.autoIncrementedPrimaryKey("id")
                tableDefinition.column("track_id", .integer)
                    .references("tracks", column: "id", onDelete: .cascade, onUpdate: .cascade)
                tableDefinition.column("remote_item_id", .text)
                tableDefinition.column("source", .text)
                tableDefinition.column("position", .integer).notNull()
                tableDefinition.uniqueKey(["position"])
            }

            try db.execute(sql: """
                INSERT INTO queue (id, track_id, remote_item_id, source, position)
                SELECT id, track_id, NULL, NULL, position
                FROM queue_old
            """)

            try db.drop(table: "queue_old")

            try db.create(index: "idx_queue_position", on: "queue", columns: ["position"], ifNotExists: true)
            try db.create(index: "idx_queue_track", on: "queue", columns: ["track_id"], ifNotExists: true)
            try db.create(index: "idx_queue_remote_item", on: "queue", columns: ["remote_item_id"], ifNotExists: true)

            Logger.info("Queue remote support migration completed")
        }

        // Add new migrations here as: migrator.registerMigration("v7_description") { db in ... }

        return migrator
    }

    /// Apply all pending migrations to the database
    static func migrate(_ dbQueue: DatabaseQueue) throws {
        let migrator = setupMigrator()
        try migrator.migrate(dbQueue)

        Logger.info("Database migrations completed")
    }

    /// Check if there are unapplied migrations
    static func hasUnappliedMigrations(_ dbQueue: DatabaseQueue) -> Bool {
        do {
            let migrator = setupMigrator()
            return try dbQueue.read { db in
                try migrator.hasBeenSuperseded(db)
            }
        } catch {
            Logger.error("Failed to check migration status: \(error)")
            return false
        }
    }

    /// Get list of applied migrations
    static func appliedMigrations(_ dbQueue: DatabaseQueue) -> [String] {
        // Return empty array for now - can be implemented if needed
        []
    }
}

// MARK: - Migration Helpers

extension Database {
    /// Helper to safely add a column if it doesn't exist
    func addColumnIfNotExists(
        table: String,
        column: String,
        type: Database.ColumnType,
        defaultValue: DatabaseValueConvertible? = nil,
        notNull: Bool = false
    ) throws {
        let columns = try self.columns(in: table)
        let columnExists = columns.contains { $0.name == column }

        if !columnExists {
            try self.alter(table: table) { tableDefinition in
                var columnDef = tableDefinition.add(column: column, type)
                if let defaultValue = defaultValue {
                    columnDef = columnDef.defaults(to: defaultValue)
                }
                if notNull {
                    columnDef = columnDef.notNull()
                }
            }
        }
    }

    /// Helper to drop a column if it exists
    func dropColumnIfExists(table: String, column: String) throws {
        let columns = try self.columns(in: table)
        let columnExists = columns.contains { $0.name == column }

        if columnExists {
            try self.alter(table: table) { tableDefinition in
                tableDefinition.drop(column: column)
            }
        }
    }

    /// Helper to create an index if it doesn't exist
    func createIndexIfNotExists(
        name: String,
        table: String,
        columns: [String],
        unique: Bool = false
    ) throws {
        let indexExists = try self.indexes(on: table).contains { $0.name == name }

        if !indexExists {
            try self.create(
                index: name,
                on: table,
                columns: columns,
                unique: unique,
                ifNotExists: true
            )
        }
    }

    /// Helper to drop an index if it exists
    func dropIndexIfExists(_ name: String) throws {
        // Note: We need to find which table the index belongs to
        // For now, we'll try to drop it and ignore errors if it doesn't exist
        do {
            try self.drop(index: name)
        } catch {
            // Index might not exist, which is fine
        }
    }

    /// Helper to rename a table if it exists
    func renameTableIfExists(from oldName: String, to newName: String) throws {
        if try self.tableExists(oldName) && !self.tableExists(newName) {
            try self.rename(table: oldName, to: newName)
        }
    }

    /// Helper to create a table only if it doesn't exist
    func createTableIfNotExists(
        _ name: String,
        body: (TableDefinition) throws -> Void
    ) throws {
        try self.create(table: name, ifNotExists: true, body: body)
    }

    /// Helper to drop a table if it exists
    func dropTableIfExists(_ name: String) throws {
        if try self.tableExists(name) {
            try self.drop(table: name)
        }
    }

    /// Helper to rename a column if it exists
    func renameColumnIfExists(
        table: String,
        from oldName: String,
        to newName: String
    ) throws {
        let columns = try self.columns(in: table)
        let oldExists = columns.contains { $0.name == oldName }
        let newExists = columns.contains { $0.name == newName }

        if oldExists && !newExists {
            try self.alter(table: table) { tableDefinition in
                tableDefinition.rename(column: oldName, to: newName)
            }
        }
    }
}
