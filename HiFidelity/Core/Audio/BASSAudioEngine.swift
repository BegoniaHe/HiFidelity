//
//  BASSAudioEngine.swift
//  HiFidelity
//
//  Created by Varun Rathod on 14/11/25.
//

import Bass        // Core BASS audio library
import CoreAudio
import Foundation

/// BASS audio engine for high-quality audio playback
/// Uses BASS library from un4seen.com via CBass Swift wrapper
@MainActor
class BASSAudioEngine {
    // MARK: - Properties

    internal var currentStream: HSTREAM = 0
    internal var nextStream: HSTREAM = 0  // For gapless playback
    internal var currentURL: URL?  // Track current playing URL for logging
    internal var isInitialized = false
    internal var loadedPlugins: [HPLUGIN] = []
    @MainActor internal var settings: AudioSettings { AudioSettings.shared }
    @MainActor internal var effectsManager: AudioEffectsManager { AudioEffectsManager.shared }
    @MainActor internal var dacManager: DACManager { DACManager.shared }

    weak var delegate: BASSAudioEngineDelegate?

    // MARK: - Initialization

    init() {
        initializeBASSEngine()
        observeSettingsChanges()
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            cleanup()
        }
    }
}
