//  AudioEffectsManager+Effects.swift
//  HiFidelity
//
//  Effect management helpers for AudioEffectsManager
//

import Bass
import BassFX
import Foundation

extension AudioEffectsManager {
    // MARK: - Effect Management

    func removeEffect(_ key: String) {
        // Remove specific effect
        if let fx = activeEffects[key] {
            BASS_ChannelRemoveFX(currentStream, fx)
            activeEffects.removeValue(forKey: key)
            Logger.debug("Removed effect: \(key)")
        }
    }

    func removeAllEffects() {
        guard currentStream != 0 else {
            activeEffects.removeAll()
            return
        }

        for (key, fx) in activeEffects {
            BASS_ChannelRemoveFX(currentStream, fx)
            Logger.debug("Removed effect: \(key)")
        }

        activeEffects.removeAll()
    }

    func reapplyEffects() {
        guard currentStream != 0 else { return }

        Logger.debug("Reapplying effects to new stream")

        if isEqualizerEnabled {
            applyEqualizer()
            applyPreamp()
        }

        if isReverbEnabled {
            applyReverb()
        }
    }
}
