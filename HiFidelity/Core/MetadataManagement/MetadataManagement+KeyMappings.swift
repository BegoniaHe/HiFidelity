//  MetadataManagement+KeyMappings.swift
//  HiFidelity
//
//  Created by Varun Rathod on 23/10/25.
//

import AVFoundation
import Foundation

extension MetadataManagement {
    // MARK: - Metadata Key Mappings

    enum MetadataKeyType {
        case composer, genre, year, albumArtist, trackNumber, discNumber, artwork
        case copyright, bpm, comment

        var keys: [String] {
            switch self {
            case .composer:
                return [
                    "composer", "©wrt", "\u{00A9}wrt", "TCOM", "TCM",
                    AVMetadataKey.commonKeyCreator.rawValue,
                    AVMetadataKey.iTunesMetadataKeyComposer.rawValue,
                    AVMetadataKey.id3MetadataKeyComposer.rawValue,
                    AVMetadataKey.quickTimeMetadataKeyProducer.rawValue,
                ]

            case .genre:
                return [
                    "genre", "gnre", "©gen", "\u{00A9}gen", "TCON",
                    AVMetadataKey.id3MetadataKeyContentType.rawValue,
                    AVMetadataKey.iTunesMetadataKeyUserGenre.rawValue,
                    AVMetadataKey.quickTimeMetadataKeyGenre.rawValue,
                ]

            case .year:
                return [
                    "year", "date", "©day", "\u{00A9}day", "TDRC", "TYER",
                    "TYE", "TDA", "TDRL",
                    AVMetadataKey.id3MetadataKeyYear.rawValue,
                    AVMetadataKey.id3MetadataKeyRecordingTime.rawValue,
                    AVMetadataKey.iTunesMetadataKeyReleaseDate.rawValue,
                    AVMetadataKey.quickTimeMetadataKeyYear.rawValue,
                    AVMetadataKey.commonKeyCreationDate.rawValue,
                ]

            case .albumArtist:
                return [
                    "TPE2", "albumartist", "album artist",
                    AVMetadataKey.iTunesMetadataKeyAlbumArtist.rawValue,
                    AVMetadataKey.id3MetadataKeyBand.rawValue,
                ]

            case .trackNumber:
                return [
                    "TRCK", "tracknumber", "track", "trkn",
                    AVMetadataKey.id3MetadataKeyTrackNumber.rawValue,
                    AVMetadataKey.iTunesMetadataKeyTrackNumber.rawValue,
                ]

            case .discNumber:
                return [
                    "TPOS", "discnumber", "disc", "disk",
                    AVMetadataKey.iTunesMetadataKeyDiscNumber.rawValue,
                ]

            case .artwork:
                return [
                    "artwork", "covr", "apic", "pic", "cover", "albumart",
                    AVMetadataKey.commonKeyArtwork.rawValue,
                    AVMetadataKey.iTunesMetadataKeyCoverArt.rawValue,
                    AVMetadataKey.id3MetadataKeyAttachedPicture.rawValue,
                    "APIC", "PIC", "COVR",
                ]

            case .copyright:
                return [
                    "TCOP", "©cpy", "\u{00A9}cpy", "copyright",
                    AVMetadataKey.commonKeyCopyrights.rawValue,
                    AVMetadataKey.id3MetadataKeyCopyright.rawValue,
                    AVMetadataKey.iTunesMetadataKeyCopyright.rawValue,
                ]

            case .bpm:
                return [
                    "TBPM", "bpm", "beatsperminute",
                    AVMetadataKey.iTunesMetadataKeyBeatsPerMin.rawValue,
                ]

            case .comment:
                return [
                    "COMM", "comment", "©cmt", "\u{00A9}cmt",
                    AVMetadataKey.commonKeyDescription.rawValue,
                    AVMetadataKey.iTunesMetadataKeyUserComment.rawValue,
                ]
            }
        }

        var searchTerms: [String] {
            switch self {
            case .composer: return ["composer", "tcom", "wrt", "©wrt", "\u{00A9}wrt"]
            case .genre: return ["genre", "gnre", "tcon", "©gen", "\u{00A9}gen"]
            case .year: return ["year", "date", "tyer", "tdrc", "©day", "\u{00A9}day"]
            case .albumArtist: return keys // Use exact matching for album artist
            case .trackNumber: return keys // Use exact matching for track number
            case .discNumber: return keys // Use exact matching for disc number
            case .artwork: return keys // User exact matching for artwork
            case .copyright: return keys // Use exact matching for copyright
            case .bpm: return keys // Use exact matching for BPM
            case .comment: return keys // Use exact matching for comment
            }
        }
    }
}
