//
//  TrackInfoDisplay.swift
//  HiFidelity
//
//  Created by Varun Rathod

import Observation
import SwiftUI

/// Display current playing track information with artwork and favorite button
struct TrackInfoDisplay: View {
    // Don't observe the entire PlaybackController to avoid re-renders on currentTime updates
    @Bindable private var playback = PlaybackController.shared
    @Bindable var theme = AppTheme.shared

    // Only observe the specific properties we need for this view
    @State private var currentTrack: Track?
    @State private var cachedAudioQuality: String = ""

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Album artwork
            artworkView

            // Track details
            if let track = currentTrack {
                trackDetails(for: track)
            } else {
                placeholderDetails
            }

            // Buttons stack (vertical)
            VStack(spacing: DesignTokens.Spacing.xs) {
                // Favorite button on top
                if let track = currentTrack {
                    favoriteButton(for: track)
                } else {
                    Color.clear.frame(width: DesignTokens.ControlHeight.xs, height: DesignTokens.ControlHeight.xs)
                }

                // Mini Player button on bottom
                Button(action: {
                    // Hide the main window
                    if let mainWindow = NSApp.mainWindow {
                        mainWindow.orderOut(nil)
                    }
                    // Show mini player
                    MiniPlayerWindowController.show()
                }) {
                    Image(systemName: "pip.enter")
                        .font(AppFonts.bodyLarge)
                        .foregroundColor(.secondary)
                        .frame(width: DesignTokens.ControlHeight.xs, height: DesignTokens.ControlHeight.xs)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainHoverButtonStyle())
                .help("Mini Player")
            }
        }
        .frame(
            minWidth: DesignTokens.Size.Playback.trackInfoMinWidth,
            maxWidth: DesignTokens.Size.Playback.trackInfoMaxWidth,
            alignment: .leading
        )
        .onChange(of: playback.currentTrack) { _, track in
            currentTrack = track
            updateCachedAudioQuality()
        }
        .onReceive(NotificationCenter.default.publisher(for: .streamInfoDidUpdate)) { _ in
            // Also update when streamInfo changes directly
            updateCachedAudioQuality()
        }
        .onAppear {
            currentTrack = playback.currentTrack
            updateCachedAudioQuality()
        }
    }

    // MARK: - Artwork View

    @ViewBuilder
    private var artworkView: some View {
        if let track = currentTrack {
            TrackArtworkView(
                track: track,
                size: DesignTokens.Size.Artwork.md,
                cornerRadius: DesignTokens.CornerRadius.xs
            )
                .tokenShadow(DesignTokens.Shadow.level1)
        } else {
            placeholderArtwork
        }
    }

    private var placeholderArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs)
                .fill(Color(nsColor: .controlBackgroundColor))
                Image(systemName: "music.note")
                    .font(AppFonts.heading2)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.secondary.opacity(0.4))
        }
        .frame(width: DesignTokens.Size.Artwork.md, height: DesignTokens.Size.Artwork.md)
        .tokenShadow(DesignTokens.Shadow.level1)
    }

    // MARK: - Track Details

    private func trackDetails(for track: Track) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(track.title)
                .font(AppFonts.heading2)
                .lineLimit(1)
                .foregroundColor(.primary)

            Text(track.artist)
                .font(AppFonts.bodyLarge)
                .lineLimit(1)
                .foregroundColor(.secondary.opacity(0.85))

            if isStreamingTrack(track) {
                Text("Streaming")
                    .font(AppFonts.captionSmall)
                    .foregroundColor(theme.currentTheme.primaryColor)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(theme.currentTheme.primaryColor.opacity(0.14))
                    )
            }

            // Audio quality info from BASS - uses cached string for performance
            if !cachedAudioQuality.isEmpty {
                Text(cachedAudioQuality)
                    .font(AppFonts.captionSmall)
                    .foregroundColor(.secondary.opacity(0.7))
                    .monospacedDigit()
            }
        }
    }

    private var placeholderDetails: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Not Playing")
                .font(AppFonts.heading5)
                .foregroundColor(.secondary.opacity(0.7))

            Text("Select a track to play")
                .font(AppFonts.bodySmall)
                .foregroundColor(.secondary.opacity(0.6))
        }
    }

    // MARK: - Favorite Button

    private func favoriteButton(for track: Track) -> some View {
        FavoriteButton()
    }

    private struct FavoriteButton: View {
        @Bindable private var playback = PlaybackController.shared
        @Bindable var theme = AppTheme.shared
        @State private var isHovered = false

        var body: some View {
            Button(action: { playback.toggleFavorite() }) {
                Image(
                    systemName: (playback.currentTrack?.isFavorite ?? false)
                        ? "heart.fill" : "heart"
                )
                .font(AppFonts.bodyLarge)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(
                    (playback.currentTrack?.isFavorite ?? false)
                        ? theme.currentTheme.primaryColor : .secondary
                )
                .frame(width: DesignTokens.ControlHeight.sm, height: DesignTokens.ControlHeight.sm)
                .background(
                    Circle()
                        .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                .animation(
                    .spring(response: 0.2, dampingFraction: 0.8),
                    value: playback.currentTrack?.isFavorite
                )
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovered = hovering
            }
            .help(
                (playback.currentTrack?.isFavorite ?? false)
                    ? "Remove from Favorites" : "Add to Favorites")
        }
    }

    // MARK: - Audio Quality Formatting

    /// Format audio quality string - only called when streamInfo changes
    private func formatAudioQuality(_ info: BASSStreamInfo) -> String {
        let sampleRateKHz = Double(info.frequency) / 1000.0
        let channels = channelDescription(info.channels)
        let bitrateKbps = info.bitrate / 1000

        // Format: "24/96kHz 2304kbps Stereo" or "44.1kHz 1411kbps Stereo" for 16-bit
        if info.bitDepth > 0 {
            return
                "\(bitrateKbps)kbps \(channels)\n\(info.bitDepth)/\(String(format: "%.1f", sampleRateKHz))kHz "
        } else {
            return "\(bitrateKbps)kbps \(channels)\n\(String(format: "%.1f", sampleRateKHz))kHz"
        }
    }

    /// Update cached audio quality when streamInfo changes
    private func updateCachedAudioQuality() {
        if let streamInfo = playback.currentStreamInfo {
            cachedAudioQuality = formatAudioQuality(streamInfo)
        } else {
            cachedAudioQuality = ""
        }
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

    private func isStreamingTrack(_ track: Track) -> Bool {
        guard let scheme = track.url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}

// MARK: - Preview

#Preview {
    TrackInfoDisplay()
    .frame(width: DesignTokens.Size.Preview.trackInfoWidth, height: DesignTokens.Size.Preview.trackInfoHeight)
        .padding()
}
