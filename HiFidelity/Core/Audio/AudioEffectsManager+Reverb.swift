//  AudioEffectsManager+Reverb.swift
//  HiFidelity
//
//  Reverb controls for AudioEffectsManager
//

import Foundation
import Bass
import BassFX

extension AudioEffectsManager {
    // MARK: - Reverb

    /// Enable/disable reverb effect
    func setReverbEnabled(_ enabled: Bool) {
        isReverbEnabled = enabled

        if enabled {
            applyReverb()
        } else {
            removeEffect("reverb")
        }

        Logger.info("Reverb: \(enabled ? "Enabled" : "Disabled")")
    }

    /// Update reverb mix level
    /// - Parameter mix: Mix level in dB (-96 to 0, where -96 is none and 0 is max)
    func setReverbMix(_ mix: Float) {
        reverbMix = max(-96.0, min(0.0, mix))

        if isReverbEnabled {
            applyReverb()
        }
    }

    /// Apply reverb effect to current stream
    func applyReverb() {
        guard currentStream != 0, isReverbEnabled else { return }

        // Remove existing reverb
        removeEffect("reverb")

        // Add reverb effect
        let fx = BASS_ChannelSetFX(currentStream, DWORD(BASS_FX_DX8_REVERB), 0)

        if fx != 0 {
            var params = BASS_DX8_REVERB()
            params.fInGain = 0.0                    // Input gain (dB)
            params.fReverbMix = reverbMix           // Reverb mix (-96 to 0 dB)
            params.fReverbTime = 1500.0             // Reverb time (ms)
            params.fHighFreqRTRatio = 0.5           // High-frequency RT ratio

            BASS_FXSetParameters(fx, &params)

            activeEffects["reverb"] = fx
            Logger.debug("Applied reverb: mix=\(reverbMix) dB")
        } else {
            let errorCode = BASS_ErrorGetCode()
            Logger.error("Failed to apply reverb, error: \(errorCode)")
        }
    }
}
