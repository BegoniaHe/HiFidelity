//
//  URLSchemeRouter.swift
//  HiFidelity
//
//  Handles hifidelity:// URL scheme for remote control of playback,
//  volume, device switching, and mini player.
//
//

import AppKit
import Foundation

/// Routes incoming hifidelity:// URLs to the appropriate controller actions
@MainActor
enum URLSchemeRouter {
    // MARK: - Supported Actions

    /// All recognized control actions
    enum Action: String, CaseIterable {
        case playNext = "play-next"
        case playPrevious = "play-previous"
        case togglePlayStop = "toggle-play-stop"
        case play = "play"
        case stop = "stop"
        case volumeUp = "volume-up"
        case volumeDown = "volume-down"
        case deviceNext = "device-next"
        case deviceDefault = "device-default"
        case toggleMiniplayer = "toggle-miniplayer"
    }

    /// Default volume step in percentage (1–100)
    private static let defaultVolumeStep: Int = 10

    // MARK: - Public Entry Point

    /// Handle an incoming URL. Returns true if the URL was recognized and handled.
    @discardableResult
    static func handleURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "hifidelity" else {
            Logger.warning("[URLScheme] Ignored URL with unknown scheme: \(url)")
            return false
        }

        // Expected format: hifidelity://control/<action>?step=<value>
        guard url.host?.lowercased() == "control" else {
            Logger.warning("[URLScheme] Unknown host '\(url.host ?? "nil")' — expected 'control'")
            return false
        }

        // Extract action from path (strip leading /)
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !path.isEmpty, let action = Action(rawValue: path) else {
            let known = Action.allCases.map(\.rawValue).joined(separator: ", ")
            Logger.warning("[URLScheme] Unknown action '\(path)'. Known actions: \(known)")
            return false
        }

        // Parse optional query parameters
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems ?? []
        let params = Dictionary(queryItems.compactMap { item in
            item.value.map { (item.name, $0) }
        }, uniquingKeysWith: { _, last in last })

        Logger.info("[URLScheme] Handling action: \(action.rawValue)")

        dispatch(action: action, params: params)
        return true
    }

    // MARK: - Dispatch

    private static func dispatch(action: Action, params: [String: String]) {
        switch action {
        // MARK: Playback
        case .playNext:
            PlaybackController.shared.next()

        case .playPrevious:
            PlaybackController.shared.previous()

        case .togglePlayStop:
            if PlaybackController.shared.isPlaying {
                PlaybackController.shared.stop()
            } else {
                PlaybackController.shared.play()
            }

        case .play:
            PlaybackController.shared.play()

        case .stop:
            PlaybackController.shared.stop()

        // MARK: Volume
        case .volumeUp:
            adjustVolume(up: true, params: params)

        case .volumeDown:
            adjustVolume(up: false, params: params)

        // MARK: Device
        case .deviceNext:
            switchToNextDevice()

        case .deviceDefault:
            let success = DACManager.shared.switchToSystemDefault()
            Logger.info("[URLScheme] Switch to system default device: \(success ? "OK" : "failed")")

        // MARK: Mini Player
        case .toggleMiniplayer:
            MiniPlayerWindowController.toggle()
        }
    }

    // MARK: - Volume Helpers

    private static func adjustVolume(up: Bool, params: [String: String]) {
        let stepPercent: Int
        if let raw = params["step"], let parsed = Int(raw), (1...100).contains(parsed) {
            stepPercent = parsed
        } else {
            stepPercent = defaultVolumeStep
            if let raw = params["step"] {
                Logger.warning("[URLScheme] Invalid step '\(raw)', using default \(defaultVolumeStep)%")
            }
        }

        let delta = Double(stepPercent) / 100.0
        let current = PlaybackController.shared.volume

        if up {
            PlaybackController.shared.volume = min(current + delta, 1.0)
        } else {
            PlaybackController.shared.volume = max(current - delta, 0.0)
        }

        let newPercent = Int(PlaybackController.shared.volume * 100)
        Logger.info("[URLScheme] Volume \(up ? "up" : "down") by \(stepPercent)% → \(newPercent)%")
    }

    // MARK: - Device Helpers

    private static func switchToNextDevice() {
        let dac = DACManager.shared
        let devices = dac.availableDevices

        guard !devices.isEmpty else {
            Logger.warning("[URLScheme] device-next: no available devices")
            return
        }

        // Find current device index; if not found start from the beginning
        let currentIndex = devices.firstIndex(where: { $0.id == dac.currentDeviceID })
        let nextIndex: Int
        if let idx = currentIndex {
            nextIndex = (idx + 1) % devices.count
        } else {
            nextIndex = 0
            Logger.warning("[URLScheme] device-next: current device not in list, selecting first")
        }

        let nextDevice = devices[nextIndex]
        let success = dac.switchToDevice(nextDevice)
        Logger.info("[URLScheme] device-next: switched to '\(nextDevice.name)' — \(success ? "OK" : "failed")")
    }
}
