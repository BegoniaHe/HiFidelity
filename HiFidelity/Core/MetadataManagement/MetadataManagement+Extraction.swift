//  MetadataManagement+Extraction.swift
//  HiFidelity
//
//  AVFoundation metadata extraction removed.
//  This file now delegates to TagLib to avoid AVFoundation dependency.
//

import Foundation

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
        return TagLibMetadataManager.extractMetadata(from: url)
    }
}
