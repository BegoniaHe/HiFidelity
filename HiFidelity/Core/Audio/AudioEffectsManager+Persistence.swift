//  AudioEffectsManager+Persistence.swift
//  HiFidelity
//
//  UserDefaults persistence for AudioEffectsManager
//

import Foundation

extension AudioEffectsManager {
    // MARK: - Persistence

    /// Load equalizer settings from UserDefaults
    func loadSettings() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        // Load equalizer state
        isEqualizerEnabled = defaults.bool(forKey: SettingsKey.isEqualizerEnabled.rawValue)

        // Load preamp gain
        preampGain = defaults.object(forKey: SettingsKey.preampGain.rawValue) as? Double ?? 0.0

        // Load equalizer bands
        if let savedBands = defaults.array(forKey: SettingsKey.equalizerBands.rawValue) as? [Float] {
            if savedBands.count == 10 {
                equalizerBands = savedBands
            }
        }

        // Load reverb settings
        isReverbEnabled = defaults.bool(forKey: SettingsKey.isReverbEnabled.rawValue)
        reverbMix = defaults.object(forKey: SettingsKey.reverbMix.rawValue) as? Float ?? -12.0

        // Load current preset info
        currentPresetName = defaults.string(forKey: SettingsKey.currentPresetName.rawValue) ?? "Flat"
        if let presetTypeString = defaults.string(forKey: SettingsKey.currentPresetType.rawValue),
           let presetType = PresetType(rawValue: presetTypeString) {
            currentPresetType = presetType
        } else {
            currentPresetType = .builtin
        }

        // Load custom presets
        if let presetsData = defaults.data(forKey: SettingsKey.customPresets.rawValue) {
            do {
                let decoder = JSONDecoder()
                customPresets = try decoder.decode([CustomEQPreset].self, from: presetsData)
            } catch {
                Logger.error("Failed to load custom presets: \(error)")
                customPresets = []
            }
        }

        Logger.info("Loaded audio effects settings from UserDefaults")
        Logger.debug("EQ Enabled: \(isEqualizerEnabled), Preset: \(currentPresetName) (\(currentPresetType.rawValue))")
        Logger.debug("Bands: \(equalizerBands), Preamp: \(preampGain) dB")
        Logger.debug("Reverb Enabled: \(isReverbEnabled), Mix: \(reverbMix) dB")
        Logger.debug("Custom Presets: \(customPresets.count)")
    }

    /// Save equalizer settings to UserDefaults
    func saveSettings() {
        // Save equalizer state
        defaults.set(isEqualizerEnabled, forKey: SettingsKey.isEqualizerEnabled.rawValue)

        // Save preamp gain
        defaults.set(preampGain, forKey: SettingsKey.preampGain.rawValue)

        // Save equalizer bands
        defaults.set(equalizerBands, forKey: SettingsKey.equalizerBands.rawValue)

        // Save current preset info
        defaults.set(currentPresetName, forKey: SettingsKey.currentPresetName.rawValue)
        defaults.set(currentPresetType.rawValue, forKey: SettingsKey.currentPresetType.rawValue)

        // Save reverb settings
        defaults.set(isReverbEnabled, forKey: SettingsKey.isReverbEnabled.rawValue)
        defaults.set(reverbMix, forKey: SettingsKey.reverbMix.rawValue)

        // Save custom presets
        saveCustomPresets()

        Logger.debug("Saved audio effects settings to UserDefaults")
    }

    /// Save custom presets to UserDefaults
    func saveCustomPresets() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(customPresets)
            defaults.set(data, forKey: SettingsKey.customPresets.rawValue)
            Logger.debug("Saved \(customPresets.count) custom presets")
        } catch {
            Logger.error("Failed to save custom presets: \(error)")
        }
    }
}
