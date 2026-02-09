//  MetadataManagement+CoreProcessing.swift
//  HiFidelity
//
//  Created by Varun Rathod on 23/10/25.
//

import AVFoundation
import Foundation

extension MetadataManagement {
    static func processCommonKey(_ commonKey: AVMetadataKey?, value: String, into metadata: inout TrackMetadata) {
        guard let commonKey = commonKey else { return }

        switch commonKey {
        case .commonKeyTitle where metadata.title == nil:
            metadata.title = value

        case .commonKeyArtist where metadata.artist == nil:
            metadata.artist = value

        case .commonKeyAlbumName where metadata.album == nil:
            metadata.album = value

        case .commonKeyCreator where metadata.composer == nil:
            metadata.composer = value

        default:
            break
        }
    }

    static func processCoreMetadata(
        keyString: String,
        identifier: String,
        commonKey: String,
        value: String,
        into metadata: inout TrackMetadata
    ) {
        // Composer
        if metadata.composer == nil && isKeyOfType(.composer, keyString, identifier, commonKey) {
            metadata.composer = value
        }

        // Genre
        if metadata.genre == nil && isKeyOfType(.genre, keyString, identifier, commonKey) {
            metadata.genre = value
        }

        // Year
        if (metadata.year == nil || metadata.year?.isEmpty == true) &&
            isKeyOfType(.year, keyString, identifier, commonKey) {
            metadata.year = extractYear(from: value)
        }

        // Album Artist
        if metadata.albumArtist == nil && isKeyOfType(.albumArtist, keyString, identifier, commonKey) {
            metadata.albumArtist = value
        }

        // Track Number - Add special handling for simple "track" key
        if metadata.trackNumber == nil {
            let validTrackKeys: Set<String> = ["tracknumber", "trck", "trkn", "track"]
            let isTrackField = isKeyOfType(.trackNumber, keyString, identifier, commonKey) ||
                validTrackKeys.contains(keyString.lowercased())

            if isTrackField {
                let (track, total) = parseNumbering(value)
                metadata.trackNumber = track.flatMap { Int($0) }
                metadata.totalTracks = total.flatMap { Int($0) }
            }
        }

        // Disc Number - Add special handling for simple "disc" key
        if metadata.discNumber == nil {
            let isDiscField = isKeyOfType(.discNumber, keyString, identifier, commonKey) ||
            keyString.lowercased() == "disc" ||
            keyString.lowercased() == "disk"

            if isDiscField {
                let (disc, total) = parseNumbering(value)
                metadata.discNumber = disc.flatMap { Int($0) }
                metadata.totalDiscs = total.flatMap { Int($0) }
            }
        }

        // Copyright
        if metadata.extended.copyright == nil && isKeyOfType(.copyright, keyString, identifier, commonKey) {
            metadata.extended.copyright = value
        }

        // BPM
        if metadata.bpm == nil && isKeyOfType(.bpm, keyString, identifier, commonKey) {
            metadata.bpm = Int(value)
        }

        // Comment
        if metadata.extended.comment == nil && isKeyOfType(.comment, keyString, identifier, commonKey) {
            metadata.extended.comment = value
        }
    }

    static func extractExtendedFields(
        _ keyString: String,
        _ identifier: String,
        _ value: String,
        into metadata: inout TrackMetadata
    ) {
        let lowercaseKey = keyString.lowercased()
        let lowercaseIdentifier = identifier.lowercased()

        // Handle release dates specially
        if lowercaseKey.contains("releasedate") || lowercaseKey == "tdrl" {
            metadata.releaseDate = value
            if metadata.year == nil || metadata.year?.isEmpty == true {
                let extractedYear = extractYear(from: value)
                if !extractedYear.isEmpty {
                    metadata.year = extractedYear
                }
            }
        } else if lowercaseKey.contains("originaldate") || lowercaseKey == "tdor" {
            metadata.originalReleaseDate = value
            if metadata.year == nil || metadata.year?.isEmpty == true {
                let extractedYear = extractYear(from: value)
                if !extractedYear.isEmpty {
                    metadata.year = extractedYear
                }
            }
        }

        // Apply extended field mappings
        for mapping in ExtendedFieldMapping.mappings {
            if mapping.conditions.contains(where: { $0(lowercaseKey) || $0(lowercaseIdentifier) }) {
                mapping.action(value, &metadata)
                break // Only apply first matching mapping
            }
        }

        // Handle special tag groups
        if lowercaseKey.contains("musicbrainz") || identifier.contains("MusicBrainz") {
            parseMusicBrainzTag(keyString, value, into: &metadata)
        }

        if lowercaseKey.contains("sort") || identifier.contains("sort") {
            parseSortingTag(keyString, value, into: &metadata)
        }

        if lowercaseKey.contains("replaygain") || identifier.contains("replaygain") {
            parseReplayGainTag(keyString, value, into: &metadata)
        }

        if lowercaseKey.contains("itunes") || identifier.contains("iTunes") {
            parseITunesTag(keyString, value, into: &metadata)
        }
    }
}
