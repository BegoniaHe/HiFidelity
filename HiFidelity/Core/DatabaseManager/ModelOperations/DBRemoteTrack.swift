import Foundation
import GRDB

extension DatabaseManager {
    func upsertRemoteTracks(_ tracks: [RemoteTrack]) async throws {
        guard !tracks.isEmpty else { return }

        try await dbQueue.write { db in
            for track in tracks {
                try db.execute(
                    sql: """
                    INSERT INTO remote_tracks (
                        remote_item_id, remote_album_id, title, artist, album, album_artist, genre,
                        duration, stream_url, artwork_url, server_url, user_id, date_added, date_updated
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(remote_item_id) DO UPDATE SET
                        remote_album_id = excluded.remote_album_id,
                        title = excluded.title,
                        artist = excluded.artist,
                        album = excluded.album,
                        album_artist = excluded.album_artist,
                        genre = excluded.genre,
                        duration = excluded.duration,
                        stream_url = excluded.stream_url,
                        artwork_url = excluded.artwork_url,
                        server_url = excluded.server_url,
                        user_id = excluded.user_id,
                        date_updated = excluded.date_updated
                    """,
                    arguments: [
                        track.remoteItemId,
                        track.remoteAlbumId,
                        track.title,
                        track.artist,
                        track.album,
                        track.albumArtist,
                        track.genre,
                        track.duration,
                        track.streamURL,
                        track.artworkURL,
                        track.serverURL,
                        track.userId,
                        track.dateAdded,
                        track.dateUpdated,
                    ]
                )
            }
        }
    }

    func getRemoteTracks(limit: Int = 500) async throws -> [RemoteTrack] {
        try await dbQueue.read { db in
            try RemoteTrack
                .order(RemoteTrack.Columns.dateUpdated.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func getRemoteTracksAsTracks(limit: Int = 4000) async throws -> [Track] {
        let rows = try await getRemoteTracks(limit: limit)
        return rows.map { $0.toTrack() }
    }

    func getRemoteAlbums() async throws -> [Album] {
        let rows = try await getRemoteTracks(limit: 10_000)
        let grouped = Dictionary(grouping: rows) {
            let album = normalizeRemoteValue($0.album, fallback: "Unknown Album")
            let artist = normalizeRemoteValue($0.albumArtist ?? $0.artist, fallback: "Unknown Artist")
            return "\(album)::\(artist)"
        }

        let sortedKeys = grouped.keys.sorted()
        return sortedKeys.enumerated().compactMap { index, key in
            guard let groupRows = grouped[key], let first = groupRows.first else { return nil }
            let totalDuration = groupRows.reduce(0) { $0 + $1.duration }

            var album = Album(
                id: Int64(1_000_000 + index),
                title: normalizeRemoteValue(first.album, fallback: "Unknown Album"),
                normalizedName: normalizeRemoteValue(first.album, fallback: "Unknown Album").lowercased(),
                sortName: normalizeRemoteValue(first.album, fallback: "Unknown Album").lowercased(),
                albumArtist: normalizeRemoteValue(first.albumArtist ?? first.artist, fallback: "Unknown Artist"),
                year: nil,
                releaseType: nil,
                recordLabel: nil,
                discCount: 1,
                musicbrainzAlbumId: nil,
                releaseDate: nil,
                musicbrainzReleaseGroupId: nil,
                barcode: nil,
                catalogNumber: nil,
                releaseCountry: nil,
                trackCount: groupRows.count,
                totalDuration: totalDuration,
                isCompilation: false,
                artworkData: nil,
                dateAdded: first.dateAdded
            )

            album.isRemote = true
            album.remoteId = first.remoteAlbumId
            if let artwork = first.artworkURL {
                album.remoteArtworkURL = URL(string: artwork)
            }

            return album
        }
    }

    func getRemoteArtists() async throws -> [Artist] {
        let rows = try await getRemoteTracks(limit: 10_000)

        var artistRows: [String: [RemoteTrack]] = [:]
        for row in rows {
            let names = row.artist
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if names.isEmpty {
                artistRows["Unknown Artist", default: []].append(row)
            } else {
                for name in names {
                    artistRows[name, default: []].append(row)
                }
            }
        }

        let sortedNames = artistRows.keys.sorted()
        return sortedNames.enumerated().compactMap { index, name in
            guard let grouped = artistRows[name], let first = grouped.first else { return nil }
            let albumCount = Set(grouped.map { normalizeRemoteValue($0.album, fallback: "Unknown Album") }).count

            var artist = Artist(
                id: Int64(2_000_000 + index),
                name: name,
                normalizedName: name.lowercased(),
                sortName: name.lowercased(),
                musicbrainzArtistId: nil,
                artistType: nil,
                country: nil,
                trackCount: grouped.count,
                albumCount: albumCount,
                artworkData: nil,
                artworkSourceType: nil,
                dateAdded: first.dateAdded
            )

            artist.isRemote = true
            artist.remoteId = name
            if let artwork = grouped.first(where: { $0.artworkURL != nil })?.artworkURL {
                artist.remoteArtworkURL = URL(string: artwork)
            }

            return artist
        }
    }

    func getRemoteGenres() async throws -> [Genre] {
        let rows = try await getRemoteTracks(limit: 10_000)
        var trackCountByGenre: [String: Int] = [:]

        for row in rows {
            let names = row.genre
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if names.isEmpty {
                trackCountByGenre["Unknown Genre", default: 0] += 1
            } else {
                for name in names {
                    trackCountByGenre[name, default: 0] += 1
                }
            }
        }

        let sortedNames = trackCountByGenre.keys.sorted()
        return sortedNames.enumerated().map { index, name in
            var genre = Genre(
                id: Int64(3_000_000 + index),
                name: name,
                normalizedName: name.lowercased(),
                sortName: name.lowercased(),
                style: nil,
                trackCount: trackCountByGenre[name] ?? 0,
                dateAdded: Date()
            )
            genre.isRemote = true
            genre.remoteId = name
            return genre
        }
    }

    private func normalizeRemoteValue(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}
