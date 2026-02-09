//  MetadataManagement+ExtendedFields.swift
//  HiFidelity
//
//  Created by Varun Rathod on 23/10/25.
//

import Foundation

extension MetadataManagement {
    // MARK: - Extended Field Mappings

    struct ExtendedFieldMapping: Sendable {
        let conditions: [@Sendable (String) -> Bool]
        let action: @Sendable (String, inout TrackMetadata) -> Void

        static let mappings: [Self] = [
            // Label
            Self(
                conditions: [
                    { $0.contains("label") || $0 == "tpub" }
                ]
            ) { value, metadata in metadata.extended.label = value },

            // ISRC
            Self(
                conditions: [
                    { $0 == "tsrc" || $0.contains("isrc") }
                ]
            ) { value, metadata in metadata.extended.isrc = value },

            // Lyrics
            Self(
                conditions: [
                    { $0 == "uslt" || $0.contains("lyrics") }
                ]
            ) { value, metadata in metadata.extended.lyrics = value },

            // Original Artist
            Self(
                conditions: [
                    { $0 == "tope" || $0.contains("originalartist") }
                ]
            ) { value, metadata in metadata.extended.originalArtist = value },

            // Musical Key
            Self(
                conditions: [
                    { $0 == "tkey" || $0.contains("initialkey") || $0.contains("musicalkey") }
                ]
            ) { value, metadata in metadata.extended.key = value },

            // Personnel
            Self(
                conditions: [{ $0 == "tpe3" || $0.contains("conductor") }]
            ) { value, metadata in metadata.extended.conductor = value },
            Self(
                conditions: [{ $0 == "tpe4" || $0.contains("remixer") }]
            ) { value, metadata in metadata.extended.remixer = value },
            Self(
                conditions: [{ $0 == "tpro" || $0.contains("producer") }]
            ) { value, metadata in metadata.extended.producer = value },
            Self(
                conditions: [{ $0.contains("engineer") }]
            ) { value, metadata in metadata.extended.engineer = value },
            Self(
                conditions: [{ $0 == "text" || $0.contains("lyricist") }]
            ) { value, metadata in metadata.extended.lyricist = value },

            // Descriptive fields
            Self(
                conditions: [{ $0.contains("subtitle") || $0 == "tit3" }]
            ) { value, metadata in metadata.extended.subtitle = value },
            Self(
                conditions: [{ $0.contains("grouping") || $0 == "tit1" || $0 == "grp1" }]
            ) { value, metadata in metadata.extended.grouping = value },
            Self(
                conditions: [{ $0.contains("movement") }]
            ) { value, metadata in metadata.extended.movement = value },
            Self(
                conditions: [{ $0.contains("mood") }]
            ) { value, metadata in metadata.extended.mood = value },
            Self(
                conditions: [{ $0 == "tlan" || $0.contains("language") }]
            ) { value, metadata in metadata.extended.language = value },

            // Publisher
            Self(
                conditions: [{ $0 == "tpub" || $0.contains("publisher") }]
            ) { value, metadata in metadata.extended.publisher = value },

            // Identifiers
            Self(
                conditions: [{ $0.contains("barcode") || $0.contains("upc") }]
            ) { value, metadata in metadata.extended.barcode = value },
            Self(
                conditions: [{ $0.contains("catalog") }]
            ) { value, metadata in metadata.extended.catalogNumber = value },

            // Professional music player fields
            Self(
                conditions: [
                    { $0.contains("releasetype") ||
                      $0.contains("musicbrainz album type") ||
                      $0.contains("albumtype")
                    },
                ]
            ) { value, metadata in metadata.extended.releaseType = value },
            Self(
                conditions: [
                    { $0.contains("releasecountry") ||
                      $0.contains("musicbrainz album release country")
                    },
                ]
            ) { value, metadata in metadata.extended.releaseCountry = value },
            Self(
                conditions: [
                    { $0.contains("artisttype") ||
                      $0.contains("musicbrainz artist type")
                    },
                ]
            ) { value, metadata in metadata.extended.artistType = value },

            // Encoding
            Self(
                conditions: [{ $0 == "tenc" || $0.contains("encodedby") }]
            ) { value, metadata in metadata.extended.encodedBy = value },
            Self(
                conditions: [{ $0 == "tsse" || $0.contains("encodersettings") }]
            ) { value, metadata in metadata.extended.encoderSettings = value },
        ]
    }
}
