//
//  MenuBarView.swift
//  HiFidelity
//
//  Menu bar controls for background mode.
//

import AppKit
import Observation
import SwiftUI

struct MenuBarView: View {
    @Bindable private var playback = PlaybackController.shared

    private let volumeStep: Double = 0.1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Open HiFidelity") {
                openMainWindow()
            }

            Divider()

            Button(playback.isPlaying ? "Pause" : "Play") {
                playback.togglePlayPause()
            }

            Button("Next Track") {
                playback.next()
            }

            Button("Previous Track") {
                playback.previous()
            }

            Divider()

            Button("Volume Up") {
                adjustVolume(up: true)
            }

            Button("Volume Down") {
                adjustVolume(up: false)
            }

            Divider()

            Button("Mini Player") {
                MiniPlayerWindowController.toggle()
            }

            Divider()

            Button("Settings...") {
                NotificationCenter.default.post(name: .openSettingsWindow, object: SettingsTab.appearance)
            }

            Button("About HiFidelity") {
                NotificationCenter.default.post(name: .openSettingsAbout, object: nil)
            }

            Divider()

            Button("Quit HiFidelity") {
                NSApp.terminate(nil)
            }
        }
        .padding(8)
        .frame(minWidth: 220)
        .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
            openMainWindow()
        }
    }

    private func openMainWindow() {
        MainWindowController.show()
    }

    private func adjustVolume(up: Bool) {
        let current = playback.volume
        let newVolume = up ? min(current + volumeStep, 1.0) : max(current - volumeStep, 0.0)
        playback.volume = newVolume
    }
}
