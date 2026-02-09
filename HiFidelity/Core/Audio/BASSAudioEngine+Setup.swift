//  BASSAudioEngine+Setup.swift
//  HiFidelity
//
//  Engine setup and device handling
//

import Bass
import CoreAudio
import Foundation

extension BASSAudioEngine {
    // MARK: - Engine Setup

    func initializeBASSEngine() {
        dacManager.refreshDevice()

        // Enable hog mode if sample rate synchronization is enabled
        // DACManager will handle the hog mode and notify us to reacquire
        if settings.synchronizeSampleRate {
            _ = dacManager.enableHogMode()
        }

        // Always use a specific device number (never -1) to prevent auto-switching
        // when macOS changes the default device (e.g., when headphones are plugged in)
        let deviceNumber = findMatchingBASSDevice()
        let sampleRate = DWORD(dacManager.getCurrentDeviceSampleRate())

        let result = BASS_Init(deviceNumber, sampleRate, 0, nil, nil)

        if result == 0 {
            Logger.error("BASS initialization failed: \(BASS_ErrorGetCode())")
            isInitialized = false

            // Disable hog mode if initialization failed
            if settings.synchronizeSampleRate {
                dacManager.disableHogMode()
            }
            return
        }

        isInitialized = true

        if let deviceName = dacManager.getDeviceName() {
            Logger.info(
                "BASS initialized: \(deviceName) (device=\(deviceNumber)), rate=\(Int(sampleRate))Hz, buffer=\(settings.bufferLength)ms"
            )
        } else {
            Logger.info(
                "BASS initialized: device=\(deviceNumber), rate=\(Int(sampleRate))Hz, buffer=\(settings.bufferLength)ms"
            )
        }

        if settings.synchronizeSampleRate {
            Logger.info("Sample rate synchronization enabled - bit-perfect playback active")
        }

        // Apply user configuration
        applyAudioSettings()

        // Load plugins for extended format support
        loadPlugins()
    }

    /// Find the BASS device number that matches our CoreAudio device
    func findMatchingBASSDevice() -> Int32 {
        guard let targetDeviceName = dacManager.getDeviceName() else {
            Logger.warning("Could not get device name, using default device")
            return -1
        }

        Logger.debug("Looking for BASS device matching: \(targetDeviceName)")

        // Enumerate BASS devices
        var deviceInfo = BASS_DEVICEINFO()
        var deviceIndex: DWORD = 0

        while BASS_GetDeviceInfo(deviceIndex, &deviceInfo) != 0 {
            if let deviceName = deviceInfo.name {
                let bassDeviceName = String(cString: deviceName)
                Logger.debug(
                    "BASS device \(deviceIndex): \(bassDeviceName), enabled: \(deviceInfo.flags & DWORD(BASS_DEVICE_ENABLED) != 0)"
                )

                // Check if this BASS device matches our CoreAudio device
                // Match by exact name or if one contains the other
                let namesMatch =
                    bassDeviceName == targetDeviceName || bassDeviceName.contains(targetDeviceName)
                    || targetDeviceName.contains(bassDeviceName)

                if namesMatch && deviceInfo.flags & DWORD(BASS_DEVICE_ENABLED) != 0 {
                    Logger.info("Found matching BASS device: \(deviceIndex) - \(bassDeviceName)")
                    return Int32(deviceIndex)
                }
            }
            deviceIndex += 1
        }

        // If no exact match found, try the "Default" device as fallback
        deviceIndex = 0
        while BASS_GetDeviceInfo(deviceIndex, &deviceInfo) != 0 {
            if let deviceName = deviceInfo.name {
                let bassDeviceName = String(cString: deviceName)
                if bassDeviceName == "Default" && deviceInfo.flags & DWORD(BASS_DEVICE_ENABLED) != 0 {
                    Logger.info("Using BASS Default device as fallback: \(deviceIndex)")
                    return Int32(deviceIndex)
                }
            }
            deviceIndex += 1
        }

        // If no match found at all, use device -1 (system default)
        Logger.warning(
            "No matching BASS device found for '\(targetDeviceName)', using system default")
        return -1
    }

    /// Apply global audio settings from AudioSettings
    /// These settings affect the BASS engine globally
    func applyAudioSettings() {
        // BASS_CONFIG_BUFFER - Playback buffer length in milliseconds
        BASS_SetConfig(DWORD(BASS_CONFIG_BUFFER), DWORD(settings.bufferLength))

        // BASS_CONFIG_FLOATDSP - Let bit depth depend on source file
        // Not forcing floating-point allows bit-perfect playback at native bit depth
        BASS_SetConfig(DWORD(BASS_CONFIG_FLOATDSP), 0)

        // BASS_CONFIG_SRC - Sample rate conversion quality
        // Always use high quality as fallback, even in sync mode
        // When device rate matches track rate, no resampling occurs anyway (bit-perfect)
        // This is a safety net if device rate switch fails
        BASS_SetConfig(DWORD(BASS_CONFIG_SRC), 4)  // 64-point sinc interpolation

        if settings.synchronizeSampleRate {
            Logger.debug(
                "Applied audio settings: buffer=\(settings.bufferLength)ms, native bit depth, sync mode"
            )
        } else {
            Logger.debug(
                "Applied audio settings: buffer=\(settings.bufferLength)ms, native bit depth, SRC quality=4"
            )
        }
    }

    /// Apply per-channel settings using BASS_ChannelSetAttribute
    /// These can be changed at runtime without restart
    func applyChannelSettings() {
        guard currentStream != 0 else { return }

        // Set volume (BASS_ATTRIB_VOL: 0.0 to 1.0)
        BASS_ChannelSetAttribute(
            currentStream, DWORD(BASS_ATTRIB_VOL), Float(settings.playbackVolume))

        Logger.debug("Applied channel settings: volume=\(settings.playbackVolume)")
    }

    /// Observe settings changes and reapply
    func observeSettingsChanges() {
        // Audio settings changes (buffer, volume, etc.)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AudioSettingsChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }

            MainActor.assumeIsolated {
                Logger.debug("Audio settings changed - applying updates")

                // Handle sample rate synchronization toggle
                if self.settings.synchronizeSampleRate && !self.dacManager.isInHogMode() {
                    _ = self.dacManager.enableHogMode()
                } else if !self.settings.synchronizeSampleRate && self.dacManager.isInHogMode() {
                    self.dacManager.disableHogMode()
                }

                self.applyAudioSettings()
                self.applyChannelSettings()
            }
        }

        // Device needs reacquisition (after hog mode enabled)
        NotificationCenter.default.addObserver(
            forName: .audioDeviceNeedsReacquisition,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            MainActor.assumeIsolated {
                self.reacquireDevice()
            }
        }

        // Device change notifications
        NotificationCenter.default.addObserver(
            forName: .audioDeviceChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let device = notification.object as? AudioOutputDevice

            MainActor.assumeIsolated {
                if let device = device {
                    Logger.info("Audio device changed: \(device.name)")
                    self.handleDeviceChange(to: device)
                }
            }
        }
    }

    /// Reacquire BASS device after hog mode is enabled
    func reacquireDevice() {
        Logger.info("Reacquiring BASS device after hog mode enabled")

        let bassDeviceNumber = findMatchingBASSDevice()

        // Ensure the device is initialized
        var deviceInfo = BASS_DEVICEINFO()
        if BASS_GetDeviceInfo(DWORD(bassDeviceNumber), &deviceInfo) != 0 {
            if deviceInfo.flags & DWORD(BASS_DEVICE_INIT) == 0 {
                // Initialize device
                let sampleRate = DWORD(dacManager.getCurrentDeviceSampleRate())
                let result = BASS_Init(bassDeviceNumber, sampleRate, 0, nil, nil)
                if result == 0 {
                    Logger.error("Failed to initialize BASS device: \(BASS_ErrorGetCode())")
                    return
                }
                // Note: No need to reapply BASS_SetConfig - settings are global
            }
        }

        // Set as current device
        if BASS_SetDevice(DWORD(bassDeviceNumber)) == 0 {
            Logger.error("Failed to bass set device: \(BASS_ErrorGetCode())")
        }

        // Move existing streams
        if currentStream != 0 {
            let result = BASS_ChannelSetDevice(currentStream, DWORD(bassDeviceNumber))
            if result == 0 {
                Logger.warning("Failed to move stream: \(BASS_ErrorGetCode())")
            } else {
                Logger.info("Stream moved to reacquired device")
            }
        }
    }

    /// Handle audio device change - move streams to new device
    func handleDeviceChange(to device: AudioOutputDevice) {
        Logger.info("Handling device change to: \(device.name)")

        let newDeviceNumber = findMatchingBASSDeviceForID(device.id)
        guard newDeviceNumber != -1 else {
            Logger.error("Could not find matching BASS device for: \(device.name)")
            return
        }

        // Get current device before switching (for cleanup)
        let oldDeviceNumber = BASS_GetDevice()

        // Check if stream was playing before the device change
        let wasPlaying =
            currentStream != 0 && BASS_ChannelIsActive(currentStream) == DWORD(BASS_ACTIVE_PLAYING)
        if wasPlaying {
            Logger.debug("Stream was playing before device change")
        }

        // Step 1: Initialize new device if needed
        var deviceInfo = BASS_DEVICEINFO()
        if BASS_GetDeviceInfo(DWORD(newDeviceNumber), &deviceInfo) != 0 {
            if deviceInfo.flags & DWORD(BASS_DEVICE_INIT) == 0 {
                Logger.info("Initializing BASS device \(newDeviceNumber)")
                let result = BASS_Init(newDeviceNumber, DWORD(device.sampleRate), 0, nil, nil)
                if result == 0 {
                    Logger.error("Failed to initialize new device: \(BASS_ErrorGetCode())")
                    return
                }
                // Note: No need to reapply BASS_SetConfig, BASS_PluginLoad - they are global
            }
        }

        // Try to move existing streams
        var streamMovedSuccessfully = false

        // Step 2: Move stream(s) to new device
        if currentStream != 0 {
            streamMovedSuccessfully =
                BASS_ChannelSetDevice(currentStream, DWORD(newDeviceNumber)) != 0
            Logger.info(
                streamMovedSuccessfully
                    ? "Stream moved to new device" : "Stream move failed - reload needed")

            // If stream was moved successfully and was playing, ensure it continues playing on new device
            if streamMovedSuccessfully && wasPlaying {
                // Switch to new device to start it
                if BASS_SetDevice(DWORD(newDeviceNumber)) == 0 {
                    Logger.error("Failed to set new device context: \(BASS_ErrorGetCode())")
                }

                // Ensure the output device is started
                if BASS_IsStarted() == 0 {
                    Logger.debug("Starting output on new device")
                    if BASS_Start() == 0 {
                        Logger.warning("Failed to start output device: \(BASS_ErrorGetCode())")
                    }
                }

                // Resume playback on the new device
                let playResult = BASS_ChannelPlay(currentStream, 0)
                if playResult != 0 {
                    Logger.info("Resumed playback on new device")
                } else {
                    Logger.error("Failed to resume playback on new device: \(BASS_ErrorGetCode())")
                    streamMovedSuccessfully = false
                }
            }
        } else {
            Logger.debug("No current stream - reload will be needed if track exists")
        }

        if nextStream != 0 {
            if BASS_ChannelSetDevice(nextStream, DWORD(newDeviceNumber)) == 0 {
                BASS_StreamFree(nextStream)
                nextStream = 0
            }
        }

        // Step 3: Free old device (if it's different and was initialized)
        if oldDeviceNumber != DWORD(newDeviceNumber)
            && oldDeviceNumber != DWORD(bitPattern: Int32.max) {
            var oldDeviceInfo = BASS_DEVICEINFO()
            if BASS_GetDeviceInfo(oldDeviceNumber, &oldDeviceInfo) != 0 {
                if oldDeviceInfo.flags & DWORD(BASS_DEVICE_INIT) != 0 {
                    // Set context to old device and free it
                    if BASS_SetDevice(oldDeviceNumber) != 0 {
                        BASS_Free()
                        Logger.info("Freed old device \(oldDeviceNumber)")
                    } else {
                        Logger.warning(
                            "Could not set old device context to free it: \(BASS_ErrorGetCode())")
                    }
                }
            }
        }

        // Ensure we're back on the new device context
        if BASS_SetDevice(DWORD(newDeviceNumber)) == 0 {
            Logger.warning("Failed to restore new device context: \(BASS_ErrorGetCode())")
        }

        // Post completion notification
        // needsReload is true if stream doesn't exist OR if it exists but couldn't be moved
        let needsReload = !streamMovedSuccessfully
        Logger.info("Posting device change complete: needsReload=\(needsReload)")

        NotificationCenter.default.post(
            name: .audioDeviceChangeComplete,
            object: nil,
            userInfo: ["needsReload": needsReload]
        )
    }

    /// Find BASS device number for a specific CoreAudio device ID
    func findMatchingBASSDeviceForID(_ deviceID: AudioDeviceID) -> Int32 {
        guard let targetDeviceName = dacManager.getDeviceName() else {
            Logger.warning("Could not get device name")
            return -1
        }

        Logger.debug("Looking for BASS device matching ID \(deviceID): \(targetDeviceName)")

        // Enumerate BASS devices
        var deviceInfo = BASS_DEVICEINFO()
        var deviceIndex: DWORD = 0

        while BASS_GetDeviceInfo(deviceIndex, &deviceInfo) != 0 {
            if let deviceName = deviceInfo.name {
                let bassDeviceName = String(cString: deviceName)

                // Match by name
                let namesMatch =
                    bassDeviceName == targetDeviceName || bassDeviceName.contains(targetDeviceName)
                    || targetDeviceName.contains(bassDeviceName)

                if namesMatch && deviceInfo.flags & DWORD(BASS_DEVICE_ENABLED) != 0 {
                    Logger.info("Found matching BASS device: \(deviceIndex) - \(bassDeviceName)")
                    return Int32(deviceIndex)
                }
            }
            deviceIndex += 1
        }

        Logger.warning("No matching BASS device found for '\(targetDeviceName)'")
        return -1
    }

    /// Load BASS plugins from the Frameworks folder
    func loadPlugins() {
        guard let frameworksPath = Bundle.main.privateFrameworksPath else {
            Logger.warning("Could not find Frameworks path")
            return
        }

        // Only load decoder plugins (exclude core library, effects, and encoding)
        let decoderPlugins = [
            "libbassflac.dylib",  // FLAC decoder
            "libbassopus.dylib",  // Opus decoder
            "libbasswebm.dylib",  // WebM/VP8/VP9 decoder
            "libbasswv.dylib",  // WavPack decoder
            "libbassape.dylib",  // APE (Monkey's Audio) decoder
            "libbassdsd.dylib",  // DSD audio decoder
            "libbassmidi.dylib",  // MIDI file decoder
            "libbass_mpc.dylib",  // Musepack decoder
            "libbass_spx.dylib",  // Speex decoder
            "libbass_tta.dylib",  // TTA (True Audio) decoder
            "libbasshls.dylib",  // HLS streaming support
        ]

        Logger.debug("Loading BASS decoder plugins from: \(frameworksPath)")

        var loadedCount = 0
        var notFoundPlugins: [String] = []

        for pluginFile in decoderPlugins {
            let pluginPath = "\(frameworksPath)/\(pluginFile)"

            // Check if file exists
            guard FileManager.default.fileExists(atPath: pluginPath) else {
                notFoundPlugins.append(pluginFile)
                continue
            }

            // Try to load the plugin
            let plugin = BASS_PluginLoad(pluginPath, 0)

            if plugin != 0 {
                loadedPlugins.append(plugin)
                loadedCount += 1
                Logger.info("Loaded: \(pluginFile)")
            } else {
                let errorCode = BASS_ErrorGetCode()
                Logger.warning("Failed to load \(pluginFile): error \(errorCode)")
            }
        }

        // Log summary
        Logger.info("Loaded \(loadedCount)/\(decoderPlugins.count) decoder plugins")

        if !notFoundPlugins.isEmpty {
            Logger.debug("Plugins not found: \(notFoundPlugins.joined(separator: ", "))")
        }

        // Log core format support
        Logger.info("Core formats: MP3, MP2, MP1, OGG, WAV, AIFF")
    }
}
