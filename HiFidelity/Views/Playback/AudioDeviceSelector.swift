//
//  AudioDeviceSelector.swift
//  HiFidelity
//
//  Audio output device selector for bottom playback bar
//

import Observation
import SwiftUI

/// Audio device selector button with popover menu
struct AudioDeviceSelector: View {
    @Bindable var dacManager = DACManager.shared
    @Bindable var theme = AppTheme.shared
    @State private var showDeviceMenu = false

    var body: some View {
        Button(action: {
            showDeviceMenu.toggle()
            dacManager.refreshDeviceList()
        }) {
            Image(systemName: "hifispeaker")
                .font(AppFonts.bodyLarge)
                .foregroundColor(.secondary)
                .frame(width: DesignTokens.ControlHeight.xs, height: DesignTokens.ControlHeight.xs)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainHoverButtonStyle())
        .popover(isPresented: $showDeviceMenu, arrowEdge: .top) {
            deviceMenuContent
        }
        .help("Select Audio Output Device")
    }

    // MARK: - Device Menu Content

    private var deviceMenuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "hifispeaker")
                    .foregroundColor(theme.currentTheme.primaryColor)
                Text("Audio Output Device")
                    .font(AppFonts.heading4)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)

            Divider()

            // Device list
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    systemDefaultRow

                    Divider()

                    if dacManager.availableDevices.isEmpty {
                        Text("No output devices found")
                            .font(AppFonts.captionLarge)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(dacManager.availableDevices) { device in
                            deviceRow(device)
                        }
                    }
                }
            }
            .frame(maxHeight: DesignTokens.Size.Menu.audioDeviceMaxHeight)

            Divider()

            // Footer info
            if let currentDevice = dacManager.currentDevice {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "info.circle")
                        .font(AppFonts.captionMedium)
                    Text(
                        "\(Int(currentDevice.sampleRate)) Hz • \(channelDescription(currentDevice.channels))"
                    )
                    .font(AppFonts.captionMedium)

                    if AudioSettings.shared.synchronizeSampleRate {
                        Text("• Sync Mode")
                            .font(AppFonts.captionMedium)
                            .foregroundColor(theme.currentTheme.primaryColor)
                    }
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.sm)
            }
        }
        .frame(width: DesignTokens.Size.Menu.audioDeviceWidth)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Device Row

    private var systemDefaultRow: some View {
        Button(action: {
            selectSystemDefault()
        }) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: isSystemDefaultSelected ? "checkmark.circle.fill" : "circle")
                    .font(AppFonts.labelLarge)
                    .foregroundColor(
                        isSystemDefaultSelected
                            ? theme.currentTheme.primaryColor : .secondary.opacity(0.3)
                    )
                    .frame(width: DesignTokens.Size.Icon.xs)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("System Default")
                        .font(AppFonts.bodySmall)
                        .foregroundColor(.primary)

                    if let defaultDevice = dacManager.systemDefaultDevice {
                        HStack(spacing: DesignTokens.Spacing.xsPlus) {
                            Text(defaultDevice.name)
                                .font(AppFonts.captionMedium)
                                .foregroundColor(.secondary)

                            /*
                            Text("•")
                                .font(AppFonts.captionMedium)
                                .foregroundColor(.secondary.opacity(0.5))

                            Text("\(Int(defaultDevice.sampleRate)) Hz")
                                .font(AppFonts.captionMedium)
                                .foregroundColor(.secondary)

                            Text("•")
                                .font(AppFonts.captionMedium)
                                .foregroundColor(.secondary.opacity(0.5))

                            Text(channelDescription(defaultDevice.channels))
                                .font(AppFonts.captionMedium)
                                .foregroundColor(.secondary)
                            */
                        }
                    } else {
                        Text("No default device available")
                            .font(AppFonts.captionMedium)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            isSystemDefaultSelected
                ? theme.currentTheme.primaryColor.opacity(0.1) : Color.clear
        )
        .onHover { hovering in
            if hovering && !isSystemDefaultSelected {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func deviceRow(_ device: AudioOutputDevice) -> some View {
        Button(action: {
            selectDevice(device)
        }) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Selection indicator
                Image(systemName: isCurrentDevice(device) ? "checkmark.circle.fill" : "circle")
                    .font(AppFonts.labelLarge)
                    .foregroundColor(
                        isCurrentDevice(device)
                            ? theme.currentTheme.primaryColor : .secondary.opacity(0.3)
                    )
                    .frame(width: DesignTokens.Size.Icon.xs)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(device.name)
                        .font(AppFonts.bodySmall)
                        .foregroundColor(.primary)

                    HStack(spacing: DesignTokens.Spacing.xsPlus) {
                        Text("\(Int(device.sampleRate)) Hz")
                            .font(AppFonts.captionMedium)
                            .foregroundColor(.secondary)

                        Text("•")
                            .font(AppFonts.captionMedium)
                            .foregroundColor(.secondary.opacity(0.5))

                        Text(channelDescription(device.channels))
                            .font(AppFonts.captionMedium)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            isCurrentDevice(device) ? theme.currentTheme.primaryColor.opacity(0.1) : Color.clear
        )
        .onHover { hovering in
            if hovering && !isCurrentDevice(device) {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Actions

    private func selectDevice(_ device: AudioOutputDevice) {
        guard !isCurrentDevice(device) else { return }

        if dacManager.switchToDevice(device) {
            Logger.info("Switched to device: \(device.name)")
            showDeviceMenu = false
        }
    }

    private func selectSystemDefault() {
        guard !isSystemDefaultSelected else { return }

        if dacManager.switchToSystemDefault() {
            Logger.info("Switched to system default output")
            showDeviceMenu = false
        }
    }

    private func isCurrentDevice(_ device: AudioOutputDevice) -> Bool {
        !dacManager.followsSystemDefault && device.id == dacManager.currentDeviceID
    }

    private var isSystemDefaultSelected: Bool {
        dacManager.followsSystemDefault
    }

    private func channelDescription(_ channels: Int) -> String {
        switch channels {
        case 1: return "Mono"
        case 2: return "Stereo"
        case 4: return "4.0"
        case 6: return "5.1"
        case 8: return "7.1"
        default: return "\(channels)ch"
        }
    }
}

// MARK: - Preview

#Preview {
    AudioDeviceSelector()
        .padding()
        .frame(width: DesignTokens.Size.Preview.audioDeviceWidth, height: DesignTokens.Size.Preview.audioDeviceHeight)
}
