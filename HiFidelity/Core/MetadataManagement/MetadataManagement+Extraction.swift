//  MetadataManagement+Extraction.swift
//  HiFidelity
//
//  Created by Varun Rathod on 23/10/25.
//

import Foundation
import AVFoundation
import CoreMedia

extension MetadataManagement {

    // MARK: - Public Methods

    @available(macOS, deprecated: 13.0)
    static func extractMetadata(from url: URL, completion: @escaping (TrackMetadata) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let metadata = extractMetadataSync(from: url)
            DispatchQueue.main.async {
                completion(metadata)
            }
        }
    }

    @available(macOS, deprecated: 13.0)
    static func extractMetadataSync(from url: URL) -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        var metadata = TrackMetadata(url: url)

        let semaphore = DispatchSemaphore(value: 0)

        asset.loadValuesAsynchronously(forKeys: ["commonMetadata", "metadata", "availableMetadataFormats", "duration", "tracks"]) {
            defer { semaphore.signal() }

            var error: NSError?
            let metadataStatus = asset.statusOfValue(forKey: "commonMetadata", error: &error)
            let durationStatus = asset.statusOfValue(forKey: "duration", error: &error)

            guard metadataStatus == .loaded && durationStatus == .loaded else { return }

            // Process metadata
            processMetadataItems(asset.commonMetadata, into: &metadata)

            for format in asset.availableMetadataFormats {
                let formatMetadata = asset.metadata(forFormat: format)
                if !formatMetadata.isEmpty {
                    processMetadataItems(formatMetadata, into: &metadata)
                }
            }

            // Duration
            metadata.duration = CMTimeGetSeconds(asset.duration)

            // Audio format info
            extractAudioFormatInfo(from: asset, into: &metadata)
        }

        let timeout = DispatchTime.now() + .seconds(5)
        if semaphore.wait(timeout: timeout) == .timedOut {
            Logger.error("Timeout loading metadata for \(url.lastPathComponent)")
        }

        return metadata
    }

    // MARK: - Private Methods

    @available(macOS, deprecated: 13.0)
    private static func processMetadataItems(_ items: [AVMetadataItem], into metadata: inout TrackMetadata) {
        for item in items {
            let keyString = getKeyString(from: item)
            let identifier = item.identifier?.rawValue ?? ""
            let commonKey = item.commonKey?.rawValue ?? ""

            // Special handling for track/disc numbers which might be stored as binary data
            if keyString == "trkn" || keyString.lowercased() == "track" ||
                identifier.contains("iTunesMetadataKeyTrackNumber") {
                if let data = item.dataValue, data.count >= 8 {
                    // M4A stores track numbers as binary:
                    // bytes 2-3: track number (big endian)
                    // bytes 4-5: total tracks (big endian)
                    let trackNumber = Int(data[2]) << 8 | Int(data[3])
                    let totalTracks = Int(data[4]) << 8 | Int(data[5])

                    if trackNumber > 0 && metadata.trackNumber == nil {
                        metadata.trackNumber = trackNumber
                        if totalTracks > 0 {
                            metadata.totalTracks = totalTracks
                        }
                        continue  // Skip normal processing for this item
                    }
                }
            }

            // Similar handling for disc numbers
            if keyString == "disk" || keyString.lowercased() == "disc" ||
                identifier.contains("iTunesMetadataKeyDiscNumber") {
                if let data = item.dataValue, data.count >= 6 {
                    let discNumber = Int(data[2]) << 8 | Int(data[3])
                    let totalDiscs = Int(data[4]) << 8 | Int(data[5])

                    if discNumber > 0 && metadata.discNumber == nil {
                        metadata.discNumber = discNumber
                        if totalDiscs > 0 {
                            metadata.totalDiscs = totalDiscs
                        }
                        continue
                    }
                }
            }

            // Continue with normal string processing
            if let stringValue = getStringValue(from: item) {
                // Process common keys
                processCommonKey(item.commonKey, value: stringValue, into: &metadata)

                // Process core metadata
                processCoreMetadata(
                    keyString: keyString,
                    identifier: identifier,
                    commonKey: commonKey,
                    value: stringValue,
                    into: &metadata
                )

                // Process extended fields
                extractExtendedFields(keyString, identifier, stringValue, into: &metadata)
            }

            // Handle artwork
            if isKeyOfType(.artwork, keyString, identifier, commonKey) {
                extractArtwork(from: item, into: &metadata)
            }
        }
    }

}
