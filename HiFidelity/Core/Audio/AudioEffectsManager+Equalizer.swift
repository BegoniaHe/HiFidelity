//  AudioEffectsManager+Equalizer.swift
//  HiFidelity
//
//  Equalizer controls for AudioEffectsManager
//

import Bass
import BassFX
import Foundation

extension AudioEffectsManager {
    // MARK: - Equalizer

    /// Enable/disable 10-band parametric equalizer
    func setEqualizerEnabled(_ enabled: Bool) {
        isEqualizerEnabled = enabled

        if enabled {
            applyEqualizer()
            applyPreamp()
        } else {
            removeEffect("equalizer")
            removeEffect("preamp")
        }

        Logger.info("Equalizer: \(enabled ? "Enabled" : "Disabled")")
    }

    /// Apply preamp gain to boost or reduce overall volume
    /// Preamp works independently of whether EQ bands are enabled
    func applyPreamp() {
        guard currentStream != 0 else { return }

        // Remove previous preamp FX
        removeEffect("preamp")

        // Skip if gain = 0 dB
        guard preampGain != 0 else { return }

        // Convert dB to linear: linear = pow(10, dB / 20)
        let linearGain = powf(10.0, Float(preampGain) / 20.0)

        // Add the BASS_FX volume effect (not DX8 effect)
        let fx = BASS_ChannelSetFX(currentStream, DWORD(BASS_FX_BFX_VOLUME), 0)

        if fx != 0 {
            // Use BASS_BFX_VOLUME structure from bass_fx.h
            var params = BASS_BFX_VOLUME()
            params.lChannel = Int32(BASS_BFX_CHANALL)  // Apply to all channels
            params.fVolume = linearGain                 // Linear volume multiplier

            // Apply parameters
            BASS_FXSetParameters(fx, &params)

            // Track it
            activeEffects["preamp"] = fx

            Logger.debug("Applied preamp \(preampGain) dB (linear=\(linearGain))")
        } else {
            Logger.error("Preamp failed. Error: \(BASS_ErrorGetCode())")
        }
    }

    /// Update equalizer band gain
    /// - Parameters:
    ///   - band: Band index (0-9)
    ///   - gain: Gain in dB (-15 to +15)
    func setEqualizerBand(_ band: Int, gain: Float) {
        guard band >= 0 && band < 10 else { return }

        equalizerBands[band] = gain

        // Mark as user-modified
        if currentPresetType != .userModified {
            currentPresetType = .userModified
            currentPresetName = "Custom"
        }

        if isEqualizerEnabled {
            updateSingleEQBand(band)
        }
    }

    /// Update a single EQ band (efficient - doesn't recreate entire EQ)
    private func updateSingleEQBand(_ band: Int) {
        guard currentStream != 0, let fxEQ = activeEffects["equalizer"] else { return }

        // Get current parameters for this band
        var params = BASS_BFX_PEAKEQ()
        params.lBand = Int32(band)
        BASS_FXGetParameters(fxEQ, &params)

        // Update only the gain
        params.fGain = equalizerBands[band]
        BASS_FXSetParameters(fxEQ, &params)

        Logger.debug("Updated EQ band \(band): \(equalizerBands[band]) dB")
    }

    /// Reset all equalizer bands to 0 dB
    func resetEqualizer() {
        equalizerBands = Array(repeating: 0.0, count: 10)
        preampGain = 0.0

        // Reset to Flat preset
        currentPresetName = "Flat"
        currentPresetType = .builtin

        if isEqualizerEnabled {
            applyEqualizer()
            applyPreamp()
        }

        Logger.info("Equalizer reset to flat (0 dB)")
    }

    /// Apply a built-in preset by name
    func applyBuiltinPreset(name: String, bands: [Float]) {
        isLoadingSettings = true

        equalizerBands = bands
        currentPresetName = name
        currentPresetType = .builtin

        isLoadingSettings = false

        if isEqualizerEnabled {
            applyEqualizer()
        }

        saveSettings()
        Logger.info("Applied built-in preset: \(name)")
    }

    func applyEqualizer() {
        guard currentStream != 0 else { return }

        // Remove existing EQ effect
        removeEffect("equalizer")

        // Create ONE peaking equalizer FX handle for all bands
        let fxEQ = BASS_ChannelSetFX(currentStream, DWORD(BASS_FX_BFX_PEAKEQ), 0)

        guard fxEQ != 0 else {
            let errorCode = BASS_ErrorGetCode()
            Logger.error("Failed to create equalizer FX: error \(errorCode)")
            return
        }

        // Set up all 10 bands using the same FX handle
        var params = BASS_BFX_PEAKEQ()
        params.fBandwidth = 1.0                         // Bandwidth in octaves
        params.fQ = 0.0                                 // Not used when bandwidth is set
        params.lChannel = Int32(BASS_BFX_CHANALL)       // Apply to all channels

        for (index, gain) in equalizerBands.enumerated() {
            params.lBand = Int32(index)                 // Band number
            params.fCenter = eqFrequencies[index]       // Center frequency in Hz
            params.fGain = gain                         // Gain in dB

            BASS_FXSetParameters(fxEQ, &params)
            Logger.debug("Set EQ band \(index): \(eqFrequencies[index]) Hz, \(gain) dB")
        }

        // Store the single FX handle
        activeEffects["equalizer"] = fxEQ
        Logger.debug("Applied equalizer with all bands: \(equalizerBands)")
    }
}
