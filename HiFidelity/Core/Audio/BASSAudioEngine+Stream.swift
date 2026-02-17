//  BASSAudioEngine+Stream.swift
//  HiFidelity
//
//  Stream utilities and callbacks
//

import Bass
import Foundation

private func bassStreamEndedCallback(_: DWORD, _: DWORD, _: DWORD, _: UnsafeMutableRawPointer?) {
    Task { @MainActor in
        NotificationCenter.default.post(name: .bassStreamEnded, object: nil)
    }
}

extension BASSAudioEngine {
    // MARK: - Stream Properties

    func getDuration() -> Double {
        guard currentStream != 0 else { return 0 }

        let lengthInBytes = BASS_ChannelGetLength(currentStream, DWORD(BASS_POS_BYTE))
        guard lengthInBytes != QWORD(bitPattern: -1) else { return 0 }

        let lengthInSeconds = BASS_ChannelBytes2Seconds(currentStream, lengthInBytes)
        return lengthInSeconds
    }

    func getCurrentTime() -> Double {
        guard currentStream != 0 else { return 0 }

        let positionInBytes = BASS_ChannelGetPosition(currentStream, DWORD(BASS_POS_BYTE))
        guard positionInBytes != QWORD(bitPattern: -1) else { return 0 }

        let positionInSeconds = BASS_ChannelBytes2Seconds(currentStream, positionInBytes)
        return positionInSeconds
    }

    func seek(to timeInSeconds: Double) -> Bool {
        guard currentStream != 0 else { return false }

        let positionInBytes = BASS_ChannelSeconds2Bytes(currentStream, timeInSeconds)
        let result = BASS_ChannelSetPosition(currentStream, positionInBytes, DWORD(BASS_POS_BYTE))

        if result != 0 {
            Logger.debug("Seeked to \(timeInSeconds) seconds")
        }

        return result != 0
    }

    func setVolume(_ volume: Float) {
        guard currentStream != 0 else { return }

        // BASS volume is 0-1
        let clampedVolume = max(0.0, min(1.0, volume))
        BASS_ChannelSetAttribute(currentStream, DWORD(BASS_ATTRIB_VOL), clampedVolume)

        Logger.debug("Set volume to \(clampedVolume)")
    }

    func isPlaying() -> Bool {
        guard currentStream != 0 else { return false }

        let state = BASS_ChannelIsActive(currentStream)
        return state == DWORD(BASS_ACTIVE_PLAYING)
    }

    func isBuffering() -> Bool {
        guard currentStream != 0 else { return false }

        let state = BASS_ChannelIsActive(currentStream)
        return state == DWORD(BASS_ACTIVE_STALLED)
    }

    // MARK: - Stream End Callback

    func setupStreamEndCallback() {
        // Set up callback for when stream ends
        BASS_ChannelSetSync(
            currentStream,
            DWORD(BASS_SYNC_END),
            0,
            bassStreamEndedCallback,
            nil
        )
    }
}
