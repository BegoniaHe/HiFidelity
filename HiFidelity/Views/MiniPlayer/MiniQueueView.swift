//
//  MiniQueueView.swift
//  HiFidelity
//
//  Compact queue view for mini player
//

import SwiftUI
import Observation

/// Compact queue view for mini player window
struct MiniQueueView: View {
    @Bindable var playback = PlaybackController.shared
    @Bindable var theme = AppTheme.shared

    @State private var hoveredIndex: Int?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Queue content
            if playback.queue.isEmpty && playback.currentTrack == nil {
                emptyState
            } else {
                queueList
            }
        }
        .background(Color.black.opacity(0.05))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Queue")
                .font(AppFonts.heading5)
                .foregroundColor(.primary)

            if !playback.queue.isEmpty {
                Text("(\(playback.queue.count))")
                    .font(AppFonts.captionLarge)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Autoplay toggle
            if !playback.queue.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: playback.isAutoplayEnabled ? "infinity.circle.fill" : "infinity.circle")
                        .font(AppFonts.labelLarge)
                        .foregroundColor(playback.isAutoplayEnabled ? theme.currentTheme.primaryColor : .secondary)

                    Text("Autoplay")
                        .font(AppFonts.labelSmall)
                        .foregroundColor(playback.isAutoplayEnabled ? theme.currentTheme.primaryColor : .secondary)
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xxs)
                        .fill(playback.isAutoplayEnabled ? theme.currentTheme.primaryColor.opacity(0.15) : Color.clear)
                )
                .onTapGesture {
                    playback.isAutoplayEnabled.toggle()
                }
            }

            // Clear queue button
            if !playback.queue.isEmpty {
                Button(action: {
                    playback.clearQueue()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppFonts.bodyLarge)
                        .foregroundColor(.secondary)
                        .frame(width: DesignTokens.ControlHeight.xs, height: DesignTokens.ControlHeight.xs)
                }
                .buttonStyle(.plain)
            }

            // Close button
            Button(action: onClose) {
                Image(systemName: "chevron.down.circle.fill")
                    .font(AppFonts.bodyLarge)
                    .foregroundColor(.secondary)
                    .frame(width: DesignTokens.ControlHeight.xs, height: DesignTokens.ControlHeight.xs)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    // MARK: - Queue List

    private var queueList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Current track (if playing)
                if let currentTrack = playback.currentTrack {
                    currentTrackRow(track: currentTrack)

                    if !playback.queue.isEmpty {
                        Divider()
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                }

                // Queue items
                ForEach(Array(playback.queue.enumerated()), id: \.offset) { index, track in
                    queueItem(track: track, index: index)
                        .background(
                            hoveredIndex == index ?
                                Color.white.opacity(0.08) :
                                Color.clear
                        )
                        .onHover { hovering in
                            hoveredIndex = hovering ? index : nil
                        }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
    }

    private func currentTrackRow(track: Track) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Playing indicator
            ZStack {
                TrackArtworkView(
                    track: track,
                    size: DesignTokens.Size.Artwork.xs,
                    cornerRadius: DesignTokens.CornerRadius.xxs
                )

                // Animated playing indicator overlay
                if playback.isPlaying {
                    Color.black.opacity(0.5)
                        .cornerRadius(DesignTokens.CornerRadius.xxs)

                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        ForEach(0..<3) { index in
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.hairline)
                                .fill(theme.currentTheme.primaryColor)
                                .frame(
                                    width: DesignTokens.Size.MiniPlayer.eqBarWidth,
                                    height: CGFloat.random(
                                        in: DesignTokens.Size.MiniPlayer.eqBarMinHeight...DesignTokens.Size.MiniPlayer.eqBarMaxHeight                                    )
                                )
                                .animation(
                                    .easeInOut(duration: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.15),
                                    value: playback.isPlaying
                                )
                        }
                    }
                }
            }
            .frame(width: DesignTokens.Size.Artwork.xs, height: DesignTokens.Size.Artwork.xs)

            // Track info
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "waveform")
                        .font(AppFonts.captionSmall)
                        .foregroundColor(theme.currentTheme.primaryColor)

                    Text(track.title)
                        .font(AppFonts.labelSmall)
                        .foregroundColor(theme.currentTheme.primaryColor)
                        .lineLimit(1)
                }

                Text(track.artist)
                    .font(AppFonts.captionMedium)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DesignTokens.Spacing.xs)

            // Duration
            Text(track.formattedDuration)
                .font(AppFonts.captionSmall)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(theme.currentTheme.primaryColor.opacity(0.1))
    }

    private func queueItem(track: Track, index: Int) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Position number
            Text("\(index + 1)")
                .font(AppFonts.labelSmall)
                .foregroundColor(.secondary.opacity(0.6))
                .frame(width: DesignTokens.ControlHeight.xs)

            // Album artwork
            TrackArtworkView(track: track, size: 40, cornerRadius: DesignTokens.CornerRadius.xxs)

            // Track info
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(track.title)
                    .font(AppFonts.captionLarge)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(track.artist)
                    .font(AppFonts.captionSmall)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DesignTokens.Spacing.xs)

            // Actions on hover
            if hoveredIndex == index {
                Button(action: {
                    playback.removeFromQueue(at: index)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(AppFonts.bodyLarge)
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: DesignTokens.ControlHeight.xs, height: DesignTokens.ControlHeight.xs)
                }
                .buttonStyle(.plain)
            } else {
                Text(track.formattedDuration)
                    .font(AppFonts.captionSmall)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            playback.play(track: track)
        }
        .contextMenu {
            Button("Play Now") {
                playback.play(track: track)
            }

            Button("Remove from Queue") {
                playback.removeFromQueue(at: index)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "music.note.list")
                .font(AppFonts.displayLarge)
                .foregroundColor(.secondary.opacity(0.3))

            Text("Queue is empty")
                .font(AppFonts.bodySmall)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    MiniQueueView(onClose: {})
    .frame(width: DesignTokens.Size.Preview.miniPanelWidth, height: DesignTokens.Size.Preview.miniPanelHeight)
}
