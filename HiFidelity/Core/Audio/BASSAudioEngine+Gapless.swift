//  BASSAudioEngine+Gapless.swift
//  HiFidelity
//
//  Gapless playback support
//

import Foundation
import Bass

extension BASSAudioEngine {
    // MARK: - Gapless Playback

    /// Pre-load the next track for gapless playback
    func preloadNext(url: URL) -> Bool {
        guard isInitialized else {
            Logger.error("BASS engine not initialized")
            return false
        }

        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.error("File does not exist: \(url.path)")
            return false
        }

        // Free existing next stream if any
        if nextStream != 0 {
            BASS_StreamFree(nextStream)
            nextStream = 0
        }

        // Create stream from file for immediate playback after current track ends
        let path = url.path

        nextStream = BASS_StreamCreateFile(
            BOOL32(truncating: false),
            path,
            0,
            0,
            DWORD(BASS_STREAM_PRESCAN) // Use native bit depth from source file
        )

        if nextStream == 0 {
            let errorCode = BASS_ErrorGetCode()
            Logger.error("Failed to pre-load next stream: error \(errorCode)")
            return false
        }

        // Get next stream's sample rate and prepare device switch if needed
        if settings.synchronizeSampleRate {
            var info = BASS_CHANNELINFO()
            if BASS_ChannelGetInfo(nextStream, &info) != 0 {
                Logger.debug("Next track: \(info.freq) Hz, \(info.chans) channels")
            }
        }

        // Set up gapless transition sync on current stream
        // This triggers RIGHT BEFORE the current track ends for seamless transition
        setupGaplessSyncCallback()

        Logger.debug("Pre-loaded next track for gapless: \(url.lastPathComponent)")

        return true
    }

    /// Set up a sync callback to trigger gapless transition at the right moment
    /// This callback fires when the stream reaches near the end, allowing seamless transition
    func setupGaplessSyncCallback() {
        guard currentStream != 0, nextStream != 0 else { return }

        // Calculate position to trigger transition (50ms before the end)
        // This gives us just enough time to execute the switch without gap
        let duration = BASS_ChannelGetLength(currentStream, DWORD(BASS_POS_BYTE))
        guard duration != QWORD(bitPattern: -1) else { return }

        // Convert 50ms to bytes
        let triggerOffset = BASS_ChannelSeconds2Bytes(currentStream, 0.05) // 50ms before end
        let triggerPosition = duration > triggerOffset ? duration - triggerOffset : duration

        // Set position-based sync to trigger just before track ends
        BASS_ChannelSetSync(
            currentStream,
            DWORD(BASS_SYNC_POS),
            triggerPosition,
            { _, _, _, _ in
                // This callback fires 50ms before the track ends
                // Post notification to switch to next track
                NotificationCenter.default.post(
                    name: .bassGaplessTransition,
                    object: nil
                )
            },
            nil
        )

        Logger.debug("Gapless transition sync set at position: \(triggerPosition) bytes (50ms before end)")
    }

    /// Switch to the pre-loaded next track (gapless transition)
    /// This should be called from the sync callback for true gapless playback
    /// Works seamlessly with or without sample rate synchronization
    func switchToPreloadedTrack(volume: Float) -> Bool {
        guard nextStream != 0 else {
            Logger.error("No pre-loaded track available")
            return false
        }

        let syncMode = settings.synchronizeSampleRate
        Logger.debug("Starting gapless transition (sync mode: \(syncMode ? "ON" : "OFF"))...")

        // Get next stream's sample rate and check if device switch is needed
        var needsSampleRateSwitch = false
        var targetRate: Float64 = 0

        if syncMode {
            var info = BASS_CHANNELINFO()
            if BASS_ChannelGetInfo(nextStream, &info) != 0 {
                targetRate = Float64(info.freq)

                // Check if sample rate is different from current
                var currentInfo = BASS_CHANNELINFO()
                if BASS_ChannelGetInfo(currentStream, &currentInfo) != 0 {
                    if currentInfo.freq != info.freq {
                        needsSampleRateSwitch = true
                        Logger.debug("Sample rate change needed: \(currentInfo.freq) Hz -> \(info.freq) Hz")
                    } else {
                        Logger.debug("Sample rate unchanged: \(info.freq) Hz - no device switch needed")
                    }
                }
            }
        } else {
            // When sync is OFF, BASS handles any necessary resampling automatically
            Logger.debug("Sample rate sync disabled - BASS will handle resampling if needed")
        }

        // Prepare the next stream completely BEFORE switching
        // Apply volume and effects to next stream
        BASS_ChannelSetAttribute(nextStream, DWORD(BASS_ATTRIB_VOL), volume)
        effectsManager.setStream(nextStream)

        // CRITICAL: Do atomic switch - stop current and start next with minimal gap
        // Store the old stream handle
        let oldStream = currentStream

        // Make next stream the current stream FIRST (before stopping old)
        currentStream = nextStream
        nextStream = 0

        // Start the new current stream immediately
        let playResult = BASS_ChannelPlay(currentStream, 0)
        if playResult == 0 {
            let errorCode = BASS_ErrorGetCode()
            Logger.error("Failed to start pre-loaded stream: error \(errorCode)")

            // Restore old stream on failure
            currentStream = oldStream
            nextStream = currentStream
            return false
        }

        // NOW we can safely stop and free the old stream
        // The new one is already playing, so gap is minimal
        if oldStream != 0 {
            BASS_ChannelStop(oldStream)
            BASS_StreamFree(oldStream)
        }

        // Set up end callback for the new current stream
        setupStreamEndCallback()

        // Switch device sample rate if needed (do this AFTER starting playback to minimize gap)
        // This only happens when sync mode is ON and the rate is different
        if needsSampleRateSwitch {
            if dacManager.setDeviceSampleRate(targetRate) {
                Logger.info("✓ Device switched to \(Int(targetRate)) Hz for bit-perfect playback")
            } else {
                Logger.warning("Could not switch device rate - BASS will resample")
            }
        }

        Logger.info("✓ Gapless transition complete - seamless playback")
        return true
    }

    /// Check if next track is pre-loaded
    func hasPreloadedTrack() -> Bool {
        return nextStream != 0
    }

    /// Clear pre-loaded track
    func clearPreloadedTrack() {
        if nextStream != 0 {
            BASS_StreamFree(nextStream)
            nextStream = 0
            Logger.debug("Cleared pre-loaded track")
        }
    }
}
