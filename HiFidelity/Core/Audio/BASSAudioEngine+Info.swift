//  BASSAudioEngine+Info.swift
//  HiFidelity
//
//  Stream info and error handling
//

import Foundation
import Bass

extension BASSAudioEngine {
    // MARK: - Audio Information

    func getStreamInfo() -> BASSStreamInfo? {
        guard currentStream != 0 else { return nil }

        var info = BASS_CHANNELINFO()
        let result = BASS_ChannelGetInfo(currentStream, &info)

        guard result != 0 else { return nil }

        // Get bit depth from flags
        let bitDepth = getBitDepth(from: info.flags)

        // Calculate bitrate from file size and duration
        let fileSize = BASS_StreamGetFilePosition(currentStream, DWORD(BASS_FILEPOS_END))
        let duration = getDuration()

        // Bitrate in bps = (fileSize in bytes * 8 bits) / duration in seconds
        // Convert to kbps
        let bitrate = duration > 0 ? Int((Double(fileSize) * 8.0) / duration) : 0

        return BASSStreamInfo(
            frequency: Int(info.freq),
            channels: Int(info.chans),
            bitrate: bitrate,
            bitDepth: bitDepth
        )
    }

    /// Get bit depth from BASS channel flags
    func getBitDepth(from flags: DWORD) -> Int {
        if flags & DWORD(BASS_SAMPLE_FLOAT) != 0 {
            return 32 // Float is 32-bit
        } else if flags & DWORD(BASS_SAMPLE_8BITS) != 0 {
            return 8
        } else {
            return 16 // Default is 16-bit
        }
    }

    // MARK: - Error Handling

    func getLastError() -> String {
        let errorCode = BASS_ErrorGetCode()
        return BASSError(rawValue: Int(errorCode))?.description ?? "Unknown error (\(errorCode))"
    }
}
