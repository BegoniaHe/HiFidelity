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
                HStack(spacing: 4) {
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
                    RoundedRectangle(cornerRadius: 4)
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
                }
                .buttonStyle(.plain)
            }

            // Close button
            Button(action: onClose) {
                Image(systemName: "chevron.down.circle.fill")
                    .font(AppFonts.bodyLarge)
                    .foregroundColor(.secondary)
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
        HStack(spacing: 10) {
            // Playing indicator
            ZStack {
                TrackArtworkView(track: track, size: 40, cornerRadius: 4)

                // Animated playing indicator overlay
                if playback.isPlaying {
                    Color.black.opacity(0.5)
                        .cornerRadius(DesignTokens.CornerRadius.xxs)

                    HStack(spacing: 2) {
                        ForEach(0..<3) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(theme.currentTheme.primaryColor)
                                .frame(width: 2, height: CGFloat.random(in: 6...14))
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
            .frame(width: 40, height: 40)

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
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

            Spacer(minLength: 4)

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
        HStack(spacing: 10) {
            // Position number
            Text("\(index + 1)")
                .font(AppFonts.labelSmall)
                .foregroundColor(.secondary.opacity(0.6))
                .frame(width: 20)

            // Album artwork
            TrackArtworkView(track: track, size: 40, cornerRadius: 3)

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(AppFonts.captionLarge)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(track.artist)
                    .font(AppFonts.captionSmall)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // Actions on hover
            if hoveredIndex == index {
                Button(action: {
                    playback.removeFromQueue(at: index)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(AppFonts.bodyLarge)
                        .foregroundColor(.red.opacity(0.8))
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
        VStack(spacing: 12) {
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
        .frame(width: 550, height: 300)
}
