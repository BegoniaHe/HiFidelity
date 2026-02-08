//
//  QueuePanel.swift
//  HiFidelity
//
//  Created by Varun Rathod on 31/10/25.
//

import SwiftUI
import Observation

/// Queue panel showing upcoming tracks
struct QueuePanel: View {
    @Bindable var playback = PlaybackController.shared
    @Bindable var theme = AppTheme.shared

    @State private var hoveredIndex: Int?
    @State private var draggedIndex: Int?
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            // Header with now playing
            header

            Divider()

            // Queue list
            if playback.queue.isEmpty && playback.currentTrack == nil {
                emptyState
            } else {
                queueList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, DesignTokens.ControlHeight.playbackBar)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
            Text("Queue")
                .font(AppFonts.heading4)
                    .frame(height: DesignTokens.ControlHeight.xs)
                    .foregroundColor(.primary)

                Spacer()

                // Go to current track button (only show if there's a current track and queue)
                if playback.currentQueueIndex >= 0 && playback.currentQueueIndex < playback.queue.count {
                    Button {
                        scrollToCurrentTrack()
                    } label: {
                    Image(systemName: "scope")
                        .font(AppFonts.bodyLarge)
                            .foregroundColor(.secondary)
                            .frame(width: DesignTokens.ControlHeight.xs, height: DesignTokens.ControlHeight.xs)
                    }
                    .buttonStyle(.plain)
                    .help("Go to Current Track")
                }

                // Autoplay toggle
                AutoplayToggle()

                // Clear queue button
                if !playback.queue.isEmpty {
                    Button {
                        playback.clearQueue()
                    } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppFonts.bodyLarge)
                            .foregroundColor(.secondary)
                            .frame(width: DesignTokens.ControlHeight.xs, height: DesignTokens.ControlHeight.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func currentTrackCard(track: Track) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ZStack {
                // Artwork
                TrackArtworkView(
                    track: track,
                    size: DesignTokens.Size.Artwork.md,
                    cornerRadius: DesignTokens.CornerRadius.xs
                )

                // Play/Pause overlay for current track
                Color.black.opacity(0.5)
                    .cornerRadius(DesignTokens.CornerRadius.xxs)

                Button(action: {
                    if playback.isPlaying {
                        playback.pause()
                    } else {
                        playback.play()
                    }
                }) {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(AppFonts.heading4)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

            }
            .frame(width: DesignTokens.Size.Artwork.sm, height: DesignTokens.Size.Artwork.sm)

            // Info
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(track.title)
                    .font(AppFonts.heading5)
                    .foregroundColor(theme.currentTheme.primaryColor)
                    .lineLimit(1)

                Text(track.artist)
                    .font(AppFonts.bodySmall)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .contextMenu {
            if !track.album.isEmpty && track.album != "Unknown Album" {
                Button("Go to Album '\(track.album)'") {
                    TrackContextMenuBuilder.navigateToAlbum(track)
                }
            }

            if !track.artist.isEmpty && track.artist != "Unknown Artist" {
                Button("Go to Artist '\(track.artist)'") {
                    TrackContextMenuBuilder.navigateToArtist(track)
                }
            }

            if (!track.album.isEmpty && track.album != "Unknown Album") || (!track.artist.isEmpty && track.artist != "Unknown Artist") {
                Divider()
            }

            Button("Get Info") {
                TrackContextMenuBuilder.showTrackInfo(track)
            }
        }

    }

    // MARK: - Queue List

    private var queueList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(playback.queue.enumerated()), id: \.offset) { index, track in
                        queueItem(track: track, index: index)
                            .id(index)  // Add ID for scrolling
                            .background(
                                Group {
                                    if index == playback.currentQueueIndex {
                                        theme.currentTheme.primaryColor.opacity(0.1)
                                    } else if hoveredIndex == index {
                                        Color(nsColor: .controlBackgroundColor)
                                    } else {
                                        Color.clear
                                    }
                                }
                            )
                            .onHover { hovering in
                                hoveredIndex = hovering ? index : nil
                            }
                    }
                }
            }
            .onAppear {
                scrollProxy = proxy
            }
        }
    }

    private func queueItem(track: Track, index: Int) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(AppFonts.labelLarge)
                .foregroundColor(.secondary.opacity(0.5))
                .frame(width: DesignTokens.Size.Icon.xsPlus)

            // Album artwork thumbnail (lazy-loaded)
            TrackArtworkView(
                track: track,
                size: DesignTokens.Size.Artwork.sm,
                cornerRadius: DesignTokens.CornerRadius.xs
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: DesignTokens.Border.hairline)
            )

            // Track info
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(track.title)
                .font(index == playback.currentQueueIndex ? AppFonts.heading5 : AppFonts.bodySmall)
                    .foregroundColor(index == playback.currentQueueIndex ? theme.currentTheme.primaryColor : .primary)
                    .lineLimit(1)

            Text(track.artist)
                .font(AppFonts.bodySmall)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Actions (show on hover)
            if hoveredIndex == index {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    // Remove from queue
                    QueueRemoveButton {
                        playback.removeFromQueue(at: index)
                    }
                }
            } else {
                // Duration
            Text(track.formattedDuration)
                .font(AppFonts.bodySmall)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            Group {
                if draggedIndex == index {
                    Color(nsColor: .controlBackgroundColor).opacity(0.3)
                } else if hoveredIndex == index {
                    Color(nsColor: .controlBackgroundColor).opacity(0.5)
                } else {
                    Color.clear
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            playback.play(track: track)
        }
        .contextMenu {
            Button("Play Now") {
                playback.play(track: track)
            }

            if (!track.album.isEmpty && track.album != "Unknown Album") || (!track.artist.isEmpty && track.artist != "Unknown Artist") {
                Divider()
            }

            if !track.album.isEmpty && track.album != "Unknown Album" {
                Button("Go to Album '\(track.album)'") {
                    TrackContextMenuBuilder.navigateToAlbum(track)
                }
            }

            if !track.artist.isEmpty && track.artist != "Unknown Artist" {
                Button("Go to Artist '\(track.artist)'") {
                    TrackContextMenuBuilder.navigateToArtist(track)
                }
            }

            Divider()

            Button("Remove from Queue", role: .destructive) {
                playback.removeFromQueue(at: index)
            }
        }

        .onDrag({
            self.draggedIndex = index
            let itemProvider = NSItemProvider(object: String(index) as NSString)
            return itemProvider
        }, preview: {
            // Lightweight drag preview - just the track title
            Text(track.title)
                .font(AppFonts.labelMedium)
                .foregroundColor(.primary)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                .background(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .tokenShadow(DesignTokens.Shadow.level1)
                )
        })
        .onDrop(of: [.text], delegate: QueueDropDelegate(
            targetIndex: index,
            draggedIndex: $draggedIndex,
            playbackController: playback
        ))
    }

    // MARK: - Queue Remove Button

    private struct QueueRemoveButton: View {
        let action: () -> Void
        @State private var isHovered = false

        var body: some View {
                Button(action: action) {
                Image(systemName: "minus.circle.fill")
                    .font(AppFonts.bodyLarge)
                    .foregroundColor(isHovered ? .red.opacity(0.8) : .secondary)
                    .frame(width: DesignTokens.ControlHeight.xs, height: DesignTokens.ControlHeight.xs)
                    .contentShape(Rectangle())
                    .scaleEffect(isHovered ? 1.1 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func scrollToCurrentTrack() {
        guard let proxy = scrollProxy,
              playback.currentQueueIndex >= 0,
              playback.currentQueueIndex < playback.queue.count else {
            return
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(playback.currentQueueIndex, anchor: .center)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Image(systemName: "music.note.list")
                .font(AppFonts.displayLarge)
                .foregroundColor(.secondary.opacity(0.2))

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("No Upcoming Songs")
                    .font(AppFonts.heading2)
                    .foregroundColor(.primary)

                Text("Queue is empty. Play something to get started.")
                    .font(AppFonts.bodySmall)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.xxxxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, DesignTokens.ControlHeight.playbackBar)
    }
}

// MARK: - Drop Delegate for Drag & Drop Reordering

struct QueueDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var draggedIndex: Int?
    let playbackController: PlaybackController

    func performDrop(info: DropInfo) -> Bool {
        draggedIndex = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let fromIndex = draggedIndex else { return }

        let toIndex = targetIndex

        // Don't swap with itself
        if fromIndex == toIndex { return }

        // Perform the move
        withAnimation(.easeInOut(duration: 0.2)) {
            playbackController.moveQueueItem(from: fromIndex, to: toIndex)
            draggedIndex = toIndex
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - Autoplay Toggle

/// Toggle button for autoplay feature
private struct AutoplayToggle: View {
        @Bindable var playback = PlaybackController.shared
        @Bindable var theme = AppTheme.shared
    @State private var showTooltip = false

    var body: some View {
        Button {
            playback.isAutoplayEnabled.toggle()
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
            Text("Autoplay")
                .font(AppFonts.labelMedium)
                    .foregroundColor(playback.isAutoplayEnabled ? theme.currentTheme.primaryColor : .secondary)

            Image(systemName: playback.isAutoplayEnabled ? "infinity.circle.fill" : "infinity.circle")
                .font(AppFonts.labelLarge)
                    .foregroundColor(playback.isAutoplayEnabled ? theme.currentTheme.primaryColor : .secondary)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs)
                    .fill(playback.isAutoplayEnabled ? theme.currentTheme.primaryColor.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help("Autoplay: Automatically add recommended tracks when queue ends")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                showTooltip = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    QueuePanel()
    .frame(height: DesignTokens.Size.Preview.rightPanelHeight)
}
