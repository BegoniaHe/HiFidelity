//
//  BASSAudioEngine.swift
//  HiFidelity
//
//  Created by Varun Rathod on 14/11/25.
//

import Foundation
import CoreAudio
import Bass        // Core BASS audio library

/// BASS audio engine for high-quality audio playback
/// Uses BASS library from un4seen.com via CBass Swift wrapper
class BASSAudioEngine {
    // MARK: - Properties

    internal var currentStream: HSTREAM = 0
    internal var nextStream: HSTREAM = 0  // For gapless playback
    internal var isInitialized = false
    internal var loadedPlugins: [HPLUGIN] = []
    internal let settings = AudioSettings.shared
    internal let effectsManager = AudioEffectsManager.shared
    internal let dacManager = DACManager.shared

    weak var delegate: BASSAudioEngineDelegate?

    // MARK: - Initialization

    init() {
        initializeBASSEngine()
        observeSettingsChanges()
    }

    deinit {
        cleanup()
    }

}
