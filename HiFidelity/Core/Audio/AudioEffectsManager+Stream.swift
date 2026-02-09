//  AudioEffectsManager+Stream.swift
//  HiFidelity
//
//  Stream lifecycle management for AudioEffectsManager
//

import Bass
import BassFX
import Foundation

extension AudioEffectsManager {
    // MARK: - Stream Management

    /// Update the current stream to apply effects to
    func setStream(_ stream: HSTREAM) {
        guard stream != currentStream else { return }

        Logger.debug("AudioEffectsManager: Setting new stream \(stream)")

        // Remove all effects from old stream
        removeAllEffects()

        // Update current stream
        currentStream = stream

        // Reapply enabled effects to new stream
        reapplyEffects()
    }

    /// Remove all effects (called when stream changes or is stopped)
    func clearStream() {
        removeAllEffects()
        currentStream = 0
    }
}
