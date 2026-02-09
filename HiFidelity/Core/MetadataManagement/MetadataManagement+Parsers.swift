//  MetadataManagement+Parsers.swift
//  HiFidelity
//
//  Created by Varun Rathod on 23/10/25.
//

import Foundation

extension MetadataManagement {
    // MARK: - Specialized Parsers

    static func parseMusicBrainzTag(_ key: String, _ value: String, into metadata: inout TrackMetadata) {
        let lowercaseKey = key.lowercased()

        switch true {
        case lowercaseKey.contains("artist") && lowercaseKey.contains("id"):
            metadata.extended.musicBrainzArtistId = value

        case lowercaseKey.contains("album") && lowercaseKey.contains("id"):
            metadata.extended.musicBrainzAlbumId = value

        case lowercaseKey.contains("track") && lowercaseKey.contains("id"):
            metadata.extended.musicBrainzTrackId = value

        case lowercaseKey.contains("release") && lowercaseKey.contains("group"):
            metadata.extended.musicBrainzReleaseGroupId = value

        case lowercaseKey.contains("work") && lowercaseKey.contains("id"):
            metadata.extended.musicBrainzWorkId = value

        default:
            break
        }
    }

    static func parseSortingTag(_ key: String, _ value: String, into metadata: inout TrackMetadata) {
        let lowercaseKey = key.lowercased()

        switch true {
        case lowercaseKey.contains("albumsort") || lowercaseKey == "tsoa":
            metadata.sortAlbum = value

        case lowercaseKey.contains("albumartistsort") || lowercaseKey == "tso2":
            metadata.sortAlbumArtist = value

        case lowercaseKey.contains("artistsort") || lowercaseKey == "tsop":
            metadata.sortArtist = value

        case lowercaseKey.contains("titlesort") || lowercaseKey == "tsot":
            metadata.sortTitle = value

        case lowercaseKey.contains("composersort") || lowercaseKey == "tsoc":
            metadata.extended.sortComposer = value

        default:
            break
        }
    }

    static func parseReplayGainTag(_ key: String, _ value: String, into metadata: inout TrackMetadata) {
        let lowercaseKey = key.lowercased()

        if lowercaseKey.contains("album") {
            metadata.extended.replayGainAlbum = value
        } else if lowercaseKey.contains("track") {
            metadata.extended.replayGainTrack = value
        }
    }

    static func parseITunesTag(_ key: String, _ value: String, into metadata: inout TrackMetadata) {
        let lowercaseKey = key.lowercased()

        switch true {
        case lowercaseKey.contains("compilation"):
            metadata.compilation = (value == "1" || value.lowercased() == "true")

        case lowercaseKey.contains("gapless"):
            metadata.extended.gaplessData = value

        case lowercaseKey.contains("mediatype") || lowercaseKey.contains("stik"):
            metadata.mediaType = value

        case lowercaseKey.contains("rating"):
            if let ratingValue = Int(value) {
                metadata.rating = ratingValue / 20 // Convert 0-100 to 0-5
            }

        case lowercaseKey.contains("advisory"):
            metadata.extended.itunesAdvisory = value

        case lowercaseKey.contains("account"):
            metadata.extended.itunesAccount = value

        case lowercaseKey.contains("purchasedate"):
            metadata.extended.itunesPurchaseDate = value

        default:
            break
        }
    }
}
