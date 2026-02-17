import Foundation
import GRDB

struct RemoteTrack: Identifiable, Hashable, Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var remoteItemId: String
    var remoteAlbumId: String?
    var title: String
    var artist: String
    var album: String
    var albumArtist: String?
    var genre: String
    var duration: Double
    var streamURL: String
    var artworkURL: String?
    var serverURL: String
    var userId: String
    var dateAdded: Date
    var dateUpdated: Date

    static let databaseTableName = "remote_tracks"

    enum Columns {
        static let id = Column("id")
        static let remoteItemId = Column("remote_item_id")
        static let remoteAlbumId = Column("remote_album_id")
        static let title = Column("title")
        static let artist = Column("artist")
        static let album = Column("album")
        static let albumArtist = Column("album_artist")
        static let genre = Column("genre")
        static let duration = Column("duration")
        static let streamURL = Column("stream_url")
        static let artworkURL = Column("artwork_url")
        static let serverURL = Column("server_url")
        static let userId = Column("user_id")
        static let dateAdded = Column("date_added")
        static let dateUpdated = Column("date_updated")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case remoteItemId = "remote_item_id"
        case remoteAlbumId = "remote_album_id"
        case title
        case artist
        case album
        case albumArtist = "album_artist"
        case genre
        case duration
        case streamURL = "stream_url"
        case artworkURL = "artwork_url"
        case serverURL = "server_url"
        case userId = "user_id"
        case dateAdded = "date_added"
        case dateUpdated = "date_updated"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    func toTrack() -> Track {
        let url = URL(string: streamURL) ?? URL(fileURLWithPath: "/")
        var track = Track(url: url)
        track.title = title
        track.artist = artist
        track.album = album
        track.albumArtist = albumArtist
        track.genre = genre
        track.duration = duration
        track.composer = "Unknown Composer"
        track.year = ""
        track.dateAdded = dateAdded
        track.isMetadataLoaded = true
        track.remoteItemId = remoteItemId
        track.remoteAlbumId = remoteAlbumId
        if let artworkURL, let url = URL(string: artworkURL) {
            track.remoteArtworkURL = url
        }
        return track
    }
}
