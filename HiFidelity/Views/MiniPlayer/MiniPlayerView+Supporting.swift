//  MiniPlayerView+Supporting.swift
//  HiFidelity
//
//  Supporting types for MiniPlayerView
//

import SwiftUI
import Observation
import AppKit

// MARK: - Mini Player Panel Type

enum MiniPlayerPanel {
    case queue
    case lyrics
}

// MARK: - Visual Effect View (NSVisualEffectView wrapper)

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Volume Popover View

struct VolumePopoverView: View {
    @Bindable var playback = PlaybackController.shared
    @Bindable var theme = AppTheme.shared

    var body: some View {
        VStack(spacing: 8) {
            // Volume percentage
            Text("\(Int(playback.volume * 100))%")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .monospacedDigit()

            // Vertical volume slider
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Track background
                    Capsule()
                        .fill(Color.primary.opacity(0.15))
                        .frame(width: 4)

                    // Volume fill
                    Capsule()
                        .fill(theme.currentTheme.primaryColor)
                        .frame(width: 4, height: geometry.size.height * playback.volume)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let height = geometry.size.height
                            let volume = 1 - (value.location.y / height)
                            playback.setVolume(max(0, min(1, volume)))
                            if playback.isMuted {
                                playback.toggleMute()
                            }
                        }
                )
            }

            // Volume icon at bottom
            Button(action: {
                playback.toggleMute()
            }) {
                Image(systemName: volumeIconForPopover)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(VisualEffectView(material: .menu, blendingMode: .behindWindow))
    }

    private var volumeIconForPopover: String {
        if playback.isMuted || playback.volume == 0 {
            return "speaker.slash.fill"
        } else if playback.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if playback.volume < 0.67 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}
