//
//  AudioSettingsView.swift
//  HiFidelity
//
//  Created by Varun Rathod on 15/11/25.
//

import SwiftUI
import Observation

struct AudioSettingsView: View {
    @Bindable var settings = AudioSettings.shared
    @Bindable var effectsManager = AudioEffectsManager.shared
    @Bindable var replayGainSettings = ReplayGainSettings.shared
    @Bindable var r128Scanner = R128LoudnessScanner.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {

            // Output Device// Output Device
            settingsSection(title: "Output Device", icon: "speaker.wave.3") {
                deviceSettings
            }

            Divider()

            // Audio Effects
            settingsSection(title: "Audio Effects", icon: "waveform.badge.magnifyingglass") {
                effectsSettings
            }

            Divider()

            // ReplayGain
            settingsSection(title: "ReplayGain", icon: "waveform.path.ecg") {
                replayGainSettingsView
            }

            Divider()

            // Audio Quality
            settingsSection(title: "Audio Quality", icon: "waveform") {
                qualitySettings
            }

            Divider()

            // Reset Button
            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                    replayGainSettings.resetToDefaults()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, DesignTokens.Spacing.sm)
        }
    }

    // MARK: - Settings Sections

    private var effectsSettings: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // Reverb Toggle
            settingRow(
                label: String(localized: "Reverb"),
                description: String(localized: "Add spatial depth and ambience to audio")
            ) {
                Toggle("", isOn: Binding(
                    get: { effectsManager.isReverbEnabled },
                    set: { effectsManager.setReverbEnabled($0) }
                ))
                .toggleStyle(.switch)
            }

            // Reverb Mix
            if effectsManager.isReverbEnabled {
                settingRow(
                    label: String(localized: "Reverb Mix"),
                    description: String(localized: "Amount of reverb effect to apply")
                ) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Slider(value: Binding(
                            get: { Double(effectsManager.reverbMix) },
                            set: { effectsManager.setReverbMix(Float($0)) }
                        ), in: -96...0, step: 1)
                        .frame(width: DesignTokens.Size.Form.fieldWidth)

                        Text("\(Int(effectsManager.reverbMix)) dB")
                            .frame(width: DesignTokens.Size.Form.valueWidth, alignment: .trailing)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var replayGainSettingsView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // ReplayGain Toggle
            settingRow(
                label: String(localized: "Enable ReplayGain"),
                description: String(localized: "Automatically normalize volume across tracks")
            ) {
                Toggle("", isOn: $replayGainSettings.isEnabled)
                    .toggleStyle(.switch)
            }

            // Mode & Source Pickers
            if replayGainSettings.isEnabled {
                settingRow(
                    label: String(localized: "Mode"),
                    description: replayGainSettings.mode.description
                ) {
                    Picker("", selection: $replayGainSettings.mode) {
                        ForEach(ReplayGainMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .frame(width: DesignTokens.Size.Form.fieldWidth)
                }

                settingRow(
                    label: String(localized: "Source"),
                    description: replayGainSettings.source.description
                ) {
                    Picker("", selection: $replayGainSettings.source) {
                        ForEach(LoudnessSource.allCases, id: \.self) { source in
                            Text(source.displayName).tag(source)
                        }
                    }
                    .frame(width: DesignTokens.Size.Form.pickerWidth)
                }

                // R128 Loudness Analysis
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(String(localized: "Loudness Analysis"))
                                .font(AppFonts.labelMedium)
                            Text(String(localized: "Scan your library to calculate EBU R128 loudness for accurate normalization"))
                                .font(AppFonts.captionMedium)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if r128Scanner.isScanning {
                            Button(String(localized: "Cancel")) {
                                r128Scanner.cancelScan()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button(String(localized: "Scan Library")) {
                                r128Scanner.scanLibrary()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    // Progress indicator
                    if r128Scanner.isScanning {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            HStack {
                                ProgressView(value: r128Scanner.progress)
                                    .frame(maxWidth: .infinity)

                                Text("\(r128Scanner.scannedCount)/\(r128Scanner.totalCount)")
                                    .font(AppFonts.captionMedium)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }

                            if let currentTrack = r128Scanner.currentTrack {
                                Text("Analyzing: \(currentTrack.title)")
                                    .font(AppFonts.captionSmall)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                }
            }
        }
    }

    private var qualitySettings: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // Buffer Length
            settingRow(
                label: String(localized: "Audio Buffer"),
                description: String(localized: "Larger buffer = more stable, but higher latency")
            ) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Slider(value: Binding(
                        get: { Double(settings.bufferLength) },
                        set: { settings.bufferLength = Int($0) }
                    ), in: 100...2000, step: 100)
                    .frame(width: DesignTokens.Size.Form.fieldWidth)

                    Text("\(settings.bufferLength) ms")
                        .frame(width: DesignTokens.Size.Form.valueWideWidth, alignment: .trailing)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var deviceSettings: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // Synchronize Sample Rate
            settingRow(
                label: String(localized: "Synchronize Sample Rate with Music Player (Hog mode)"),
                description: String(localized: "Enable exclusive audio access for bit-perfect playback")
            ) {
                Toggle("", isOn: $settings.synchronizeSampleRate)
                    .toggleStyle(.switch)
            }

            // Info text when enabled
            if settings.synchronizeSampleRate {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(AppFonts.captionLarge)

                    Text(
                        "When enabled, the app takes exclusive control (hog mode) of your audio device and " +
                        "automatically switches the device sample rate to match each track (44.1kHz, 48kHz, " +
                        "96kHz, etc.) preventing BASS from resampling for true bit-perfect playback."
                    )
                        .font(AppFonts.captionMedium)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .padding(.horizontal, DesignTokens.Spacing.xs)
            }
        }
    }

    // MARK: - Helper Views

    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(AppFonts.bodyLarge)
                    .foregroundStyle(.tint)

                Text(title)
                    .font(AppFonts.heading4)
            }

            content()
        }
    }

    private func settingRow<Content: View>(
        label: String,
        description: String,
        @ViewBuilder control: () -> Content
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(label)
                    .font(AppFonts.labelMedium)

                Text(description)
                    .font(AppFonts.captionMedium)
                    .foregroundColor(.secondary)
            }

            Spacer()

            control()
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

#Preview {
    AudioSettingsView()
        .frame(width: DesignTokens.Size.Preview.audioSettingsWidth, height: DesignTokens.Size.Preview.audioSettingsHeight)
}
