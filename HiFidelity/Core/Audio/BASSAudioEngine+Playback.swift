//  BASSAudioEngine+Playback.swift
//  HiFidelity
//
//  Playback control and stream lifecycle
//

import Bass
import Foundation

extension BASSAudioEngine {
    // MARK: - Playback Control

    func load(url: URL) -> Bool {
        guard isInitialized else {
            Logger.error("BASS engine not initialized")
            return false
        }

        // Stop current stream if any
        stop()

        if url.isFileURL {
            // Check if file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                Logger.error("File does not exist: \(url.path)")
                return false
            }

            // Create stream from local file
            currentStream = BASS_StreamCreateFile(
                BOOL32(truncating: false),
                url.path,
                0,
                0,
                DWORD(BASS_STREAM_PRESCAN)
            )
        } else {
            guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
                Logger.error("Unsupported URL scheme for playback: \(url.absoluteString)")
                return false
            }

            currentStream = BASS_StreamCreateURL(
                url.absoluteString,
                0,
                DWORD(0),
                nil,
                nil
            )
        }

        if currentStream == 0 {
            let errorCode = BASS_ErrorGetCode()
            let errorDescription = getLastError()
            Logger.error("Failed to create BASS stream for '\(url.lastPathComponent)'")
            Logger.error("  URL: \(url.absoluteString)")
            Logger.error("  Error code: \(errorCode) - \(errorDescription)")
            Logger.error("  File extension: \(url.pathExtension)")

            return false
        }

        // Store the URL for logging
        self.currentURL = url

        // CRITICAL: Switch device sample rate to match track for bit-perfect playback
        // Why this is necessary:
        // - Audio devices operate at a specific sample rate (e.g., 44.1kHz, 48kHz, 96kHz)
        // - If device is at 44.1kHz and track is 96kHz, BASS will resample (quality loss)
        // - By switching device to track's rate, BASS outputs directly without resampling
        // - This is the ONLY way to achieve true bit-perfect playback
        if settings.synchronizeSampleRate {
            // Get stream info to determine actual sample rate and bit depth
            if let streamInfo = getStreamInfo() {
                Logger.info("Loaded track: \(url.lastPathComponent)")
                Logger.info(
                    "  Stream: \(streamInfo.frequency) Hz, \(streamInfo.channels) channels, \(streamInfo.bitDepth)-bit"
                )

                let targetRate = Float64(streamInfo.frequency)
                Task { @MainActor in
                    if self.dacManager.setDeviceSampleRate(targetRate) {
                        Logger.info(
                            "  Bit-perfect: Device switched to \(streamInfo.frequency) Hz (no resampling)"
                        )
                    } else {
                        Logger.warning("  Could not switch device rate, BASS will resample")
                    }
                }
            }
        }

        // Set up end-of-stream callback
        setupStreamEndCallback()

        // Apply audio effects to the new stream
        Task { @MainActor in
            self.effectsManager.setStream(currentStream)
        }

        return true
    }

    func play() -> Bool {
        guard currentStream != 0 else {
            Logger.error("No stream loaded")
            return false
        }

        // Ensure the audio output device is started
        // The output may be paused automatically if the output device becomes unavailable (e.g., disconnected)
        // or after device switches. BASS_Start() resumes the output before playing the channel.
        if BASS_IsStarted() == 0 {
            Logger.debug("Output device is paused/stopped, starting it")
            if BASS_Start() == 0 {
                let errorCode = BASS_ErrorGetCode()
                Logger.warning("Failed to start output device: \(errorCode)")
                // Continue anyway - try to play the channel
            }
        }

        let result = BASS_ChannelPlay(currentStream, 0)  // 0 = don't restart from beginning

        if result == 0 {
            let errorCode = BASS_ErrorGetCode()
            Logger.error("Failed to play stream, error: \(errorCode)")
            return false
        }

        Logger.debug("Playing stream \(currentStream) from URL: \(currentURL?.path ?? "unknown path")")
        return true
    }

    func pause() -> Bool {
        guard currentStream != 0 else { return false }

        let result = BASS_ChannelPause(currentStream)

        Logger.debug("Paused stream \(currentStream) from URL: \(currentURL?.path ?? "unknown path")")
        return result != 0
    }

    func stop() {
        guard currentStream != 0 else { return }

        // Clear effects before freeing stream
        Task { @MainActor in
            self.effectsManager.clearStream()
        }

        BASS_ChannelStop(currentStream)
        BASS_StreamFree(currentStream)
        currentStream = 0

        Logger.debug("Stopped stream \(currentStream) from URL: \(currentURL?.path ?? "unknown path")")

        func resume() -> Bool {
            return play()
        }
    }
}
