//
//  AudioEffectsManager.swift
//  HiFidelity
//
//  Manages DSP effects and custom processing for audio playback
//

import Bass
import BassFX
import Foundation
import Observation

/// Manages audio effects (DSP) for the current audio stream
/// Supports built-in BASS FX and custom DSP processing
@MainActor
@Observable
class AudioEffectsManager {
    static let shared = AudioEffectsManager()

    internal let defaults = UserDefaults.standard
    internal var isLoadingSettings = false

    // MARK: - Properties

    var isEqualizerEnabled = false {
        didSet { if !isLoadingSettings { saveSettings() } }
    }

    // Equalizer bands (10-band graphic equalizer)
    // Frequencies: 32, 64, 125, 250, 500, 1K, 2K, 4K, 8K, 16K Hz
    var equalizerBands: [Float] = Array(repeating: 0.0, count: 10) {
        didSet { if !isLoadingSettings { saveSettings() } }
    }

    var preampGain: Double = 0.0 {
        didSet {
            if !isLoadingSettings {
                applyPreamp()
                saveSettings()
            }
        }
    }

    // Reverb settings
    var isReverbEnabled = false {
        didSet { if !isLoadingSettings { saveSettings() } }
    }

    var reverbMix: Float = -12.0 {
        didSet { if !isLoadingSettings { saveSettings() } }
    }

    // Custom preset management
    var customPresets: [CustomEQPreset] = []

    // Current preset tracking
    var currentPresetName: String = "Flat"
    var currentPresetType: PresetType = .builtin

    // Effect handles (for removing effects later)
    internal var activeEffects: [String: HFX] = [:]

    internal var currentStream: HSTREAM = 0

    // Equalizer frequencies (Hz) - matching common EQ frequencies
    internal let eqFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16_000]

    // Settings keys
    enum SettingsKey: String, CaseIterable {
        case isEqualizerEnabled = "effects.equalizer.enabled"
        case equalizerBands = "effects.equalizer.bands"
        case preampGain = "effects.equalizer.preamp"
        case currentPresetName = "effects.equalizer.currentPresetName"
        case currentPresetType = "effects.equalizer.currentPresetType"
        case isReverbEnabled = "effects.reverb.enabled"
        case reverbMix = "effects.reverb.mix"
        case customPresets = "effects.equalizer.customPresets"
    }

    enum PresetType: String, Codable {
        case builtin
        case custom
        case userModified
    }

    // MARK: - Initialization

    private init() {
        Logger.info("AudioEffectsManager initialized")
        loadSettings()
    }
}

// MARK: - Custom EQ Preset Model

struct CustomEQPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var bandValues: [Float]  // 10 band values
    var preampGain: Float
    var dateCreated: Date

    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }
}
