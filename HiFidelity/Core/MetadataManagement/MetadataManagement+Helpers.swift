//  MetadataManagement+Helpers.swift
//  HiFidelity
//
//  Created by Varun Rathod on 23/10/25.
//

import AVFoundation
import CoreMedia
import Foundation

extension MetadataManagement {
    // MARK: - Helper Methods

    static func isKeyOfType(
        _ type: MetadataKeyType,
        _ key: String,
        _ identifier: String,
        _ commonKey: String
    ) -> Bool {
        // Special handling for year - exclude TDAT
        if type == .year && key.lowercased() == "tdat" {
            return false
        }

        let keyLower = key.lowercased()
        let identifierLower = identifier.lowercased()
        let commonKeyLower = commonKey.lowercased()

        // Check if the key exactly matches any of our known keys
        if type.keys.contains(where: {
            $0.lowercased() == keyLower ||
            $0.lowercased() == identifierLower ||
            $0.lowercased() == commonKeyLower
        }) {
            return true
        }

        // For some fields, also check if any part contains our search terms
        // But skip this for fields that should use exact matching only
        if type == .trackNumber || type == .discNumber {
            return false
        }

        let combined = (key + identifier + commonKey).lowercased()

        // Check search terms
        return type.searchTerms.contains { searchTerm in
            combined.contains(searchTerm.lowercased())
        }
    }

    @available(macOS, deprecated: 13.0)
    static func extractAudioFormatInfo(from asset: AVURLAsset, into metadata: inout TrackMetadata) {
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else { return }

        let formatDescriptions = audioTrack.formatDescriptions as? [CMFormatDescription] ?? []

        if let formatDescription = formatDescriptions.first {
            if let streamBasicDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                metadata.sampleRate = Int(streamBasicDesc.pointee.mSampleRate)
                metadata.channels = Int(streamBasicDesc.pointee.mChannelsPerFrame)

                if streamBasicDesc.pointee.mBitsPerChannel > 0 {
                    metadata.bitDepth = Int(streamBasicDesc.pointee.mBitsPerChannel)
                }
            }

            let audioCodec = CMFormatDescriptionGetMediaSubType(formatDescription)
            metadata.codec = fourCCToString(audioCodec)
        }

        let dataRate = audioTrack.estimatedDataRate
        if dataRate > 0 {
            metadata.bitrate = Int(dataRate / 1000)
        }
    }

    @available(macOS, deprecated: 13.0)
    static func extractArtwork(from item: AVMetadataItem, into metadata: inout TrackMetadata) {
        if let data = item.dataValue {
            metadata.artworkData = data
        } else if let value = item.value {
            if let data = value as? Data {
                metadata.artworkData = data
            } else if let data = value as? NSData {
                metadata.artworkData = data as Data
            }
        }
    }

    @available(macOS, deprecated: 13.0)
    static func getStringValue(from item: AVMetadataItem) -> String? {
        if let stringValue = item.stringValue {
            return stringValue
        }

        if let value = item.value {
            if let stringValue = value as? String {
                return stringValue
            } else if let numberValue = value as? NSNumber {
                return numberValue.stringValue
            } else if let dataValue = value as? Data {
                return String(data: dataValue, encoding: .utf8)
            }
        }

        if let dataValue = item.dataValue {
            return String(data: dataValue, encoding: .utf8)
        }

        return nil
    }

    static func getKeyString(from item: AVMetadataItem) -> String {
        guard let key = item.key else { return "" }

        if let stringKey = key as? String {
            return stringKey
        } else if let numberKey = key as? NSNumber {
            let intValue = numberKey.uint32Value

            // Check if this is "trkn" (0x74726b6e in hex)
            if intValue == 0x74726b6e {
                return "trkn"
            }

            // Check if this is "disk" (0x6469736b in hex)
            if intValue == 0x6469736b {
                return "disk"
            }

            // Convert ID3 numeric keys to string
            let id3Key = String(format: "%c%c%c%c",
                                (intValue >> 24) & 0xFF,
                                (intValue >> 16) & 0xFF,
                                (intValue >> 8) & 0xFF,
                                intValue & 0xFF)
            return id3Key
        } else {
            return String(describing: key)
        }
    }

    static func parseNumbering(_ value: String) -> (String?, String?) {
        let components = value.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespaces) }

        switch components.count {
        case 0: return (nil, nil)
        case 1: return (components[0], nil)
        default: return (components[0], components[1])
        }
    }

    static func extractYear(from dateString: String) -> String {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate if already a 4-digit year
        if trimmed.count == 4, let yearInt = Int(trimmed) {
            let currentYear = Calendar.current.component(.year, from: Date())
            if yearInt >= 1900 && yearInt <= currentYear + 10 {
                return trimmed
            }
            return ""
        }

        // Try regex for years 1900-2099
        let pattern = #"\b(19\d{2}|20\d{2})\b"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let yearRange = Range(match.range(at: 1), in: trimmed) {
            return String(trimmed[yearRange])
        }

        // Try date formatters
        let dateFormatters = [
            "yyyy-MM-dd", "yyyy/MM/dd", "yyyy.MM.dd", "yyyy",
            "dd-MM-yyyy", "dd/MM/yyyy", "MM-dd-yyyy", "MM/dd/yyyy",
            "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd HH:mm:ss",
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in dateFormatters {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                let year = Calendar.current.component(.year, from: date)
                let currentYear = Calendar.current.component(.year, from: Date())
                if year >= 1900 && year <= currentYear + 10 {
                    return String(year)
                }
            }
        }

        return ""
    }

    static func fourCCToString(_ fourCC: FourCharCode) -> String {
        // Check common audio formats first
        switch fourCC {
        case kAudioFormatMPEG4AAC: return "AAC"
        case kAudioFormatMPEGLayer3: return "MP3"
        case kAudioFormatAppleLossless: return "ALAC"
        case kAudioFormatFLAC: return "FLAC"
        case kAudioFormatLinearPCM: return "PCM"
        case kAudioFormatAC3: return "AC-3"
        case kAudioFormatMPEG4AAC_HE: return "HE-AAC"
        case kAudioFormatMPEG4AAC_HE_V2: return "HE-AACv2"

        default:
            // Convert FourCC bytes to string
            let bytes: [UInt8] = [
                UInt8((fourCC >> 24) & 0xFF),
                UInt8((fourCC >> 16) & 0xFF),
                UInt8((fourCC >> 8) & 0xFF),
                UInt8(fourCC & 0xFF),
            ]
            return String(bytes: bytes, encoding: .ascii)?
                .trimmingCharacters(in: .whitespaces) ?? "Unknown"
        }
    }
}
