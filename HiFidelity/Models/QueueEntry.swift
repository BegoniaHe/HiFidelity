//
//  QueueEntry.swift
//  HiFidelity
//
//  Persistent queue management
//

import Foundation
import GRDB

struct QueueEntry: Identifiable, Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var trackId: Int64?
    var remoteItemId: String?
    var source: String?
    var position: Int

    // MARK: - Database Configuration

    static let databaseTableName = "queue"

    enum Columns {
        static let id = Column("id")
        static let trackId = Column("track_id")
        static let remoteItemId = Column("remote_item_id")
        static let source = Column("source")
        static let position = Column("position")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case trackId = "track_id"
        case remoteItemId = "remote_item_id"
        case source
        case position
    }

    // MARK: - Relationships

    static let track = belongsTo(Track.self)
    var track: QueryInterfaceRequest<Track> {
        request(for: Self.track)
    }

    // Auto-increment id
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
