//  BASSAudioEngine+Cleanup.swift
//  HiFidelity
//
//  Cleanup and shutdown
//

import Bass
import Foundation

extension BASSAudioEngine {
    // MARK: - Cleanup

    func cleanup() {
        stop()

        if isInitialized {
            // Unload plugins
            for plugin in loadedPlugins {
                BASS_PluginFree(plugin)
            }
            loadedPlugins.removeAll()

            // Free BASS
            BASS_Free()
            isInitialized = false

            // Release hog mode
            Task { @MainActor in
                if self.dacManager.isInHogMode() {
                    self.dacManager.disableHogMode()
                }
            }

            Logger.info("BASS audio engine cleaned up")
        }
    }
}
