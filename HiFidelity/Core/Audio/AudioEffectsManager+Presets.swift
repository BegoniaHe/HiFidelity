//  AudioEffectsManager+Presets.swift
//  HiFidelity
//
//  Custom preset management for AudioEffectsManager
//

import Foundation

extension AudioEffectsManager {
    // MARK: - Custom Preset Management

    /// Save current equalizer settings as a custom preset
    func saveCustomPreset(name: String) -> Bool {
        // Check if name already exists
        if customPresets.contains(where: { $0.name == name }) {
            Logger.warning("Custom preset '\(name)' already exists")
            return false
        }

        let preset = CustomEQPreset(
            id: UUID(),
            name: name,
            bandValues: equalizerBands,
            preampGain: Float(preampGain),
            dateCreated: Date()
        )

        customPresets.append(preset)
        saveCustomPresets()

        Logger.info("Saved custom preset: \(name)")
        return true
    }

    /// Load a custom preset
    func loadCustomPreset(_ preset: CustomEQPreset) {
        isLoadingSettings = true

        equalizerBands = preset.bandValues
        preampGain = Double(preset.preampGain)
        currentPresetName = preset.name
        currentPresetType = .custom

        isLoadingSettings = false

        if isEqualizerEnabled {
            applyEqualizer()
            applyPreamp()
        }

        saveSettings()
        Logger.info("Loaded custom preset: \(preset.name)")
    }

    /// Delete a custom preset
    func deleteCustomPreset(_ preset: CustomEQPreset) {
        customPresets.removeAll { $0.id == preset.id }
        saveCustomPresets()
        Logger.info("Deleted custom preset: \(preset.name)")
    }

    /// Rename a custom preset
    func renameCustomPreset(_ preset: CustomEQPreset, newName: String) -> Bool {
        // Check if new name already exists
        if customPresets.contains(where: { $0.name == newName && $0.id != preset.id }) {
            Logger.warning("Custom preset '\(newName)' already exists")
            return false
        }

        if let index = customPresets.firstIndex(where: { $0.id == preset.id }) {
            customPresets[index].name = newName
            saveCustomPresets()
            Logger.info("Renamed preset to: \(newName)")
            return true
        }

        return false
    }

    /// Export preset to JSON
    func exportPreset(_ preset: CustomEQPreset) -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(preset)
            return String(data: data, encoding: .utf8)
        } catch {
            Logger.error("Failed to export preset: \(error)")
            return nil
        }
    }

    /// Import preset from JSON
    func importPreset(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            Logger.error("Invalid JSON string")
            return false
        }

        do {
            let decoder = JSONDecoder()
            var preset = try decoder.decode(CustomEQPreset.self, from: data)

            // Generate new ID and update date
            preset.id = UUID()
            preset.dateCreated = Date()

            // Make name unique if needed
            var uniqueName = preset.name
            var counter = 1
            while customPresets.contains(where: { $0.name == uniqueName }) {
                uniqueName = "\(preset.name) (\(counter))"
                counter += 1
            }
            preset.name = uniqueName

            customPresets.append(preset)
            saveCustomPresets()

            Logger.info("Imported custom preset: \(preset.name)")
            return true
        } catch {
            Logger.error("Failed to import preset: \(error)")
            return false
        }
    }
}
