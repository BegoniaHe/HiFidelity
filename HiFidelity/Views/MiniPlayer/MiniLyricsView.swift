//
//  MiniLyricsView.swift
//  HiFidelity
//
//  Compact lyrics view for mini player
//

import SwiftUI
import Observation
import UniformTypeIdentifiers

/// Compact lyrics view for mini player window
struct MiniLyricsView: View {
    @Bindable var playback = PlaybackController.shared
    @Bindable var theme = AppTheme.shared
    @Bindable var database = DatabaseManager.shared

    @State private var lyrics: Lyrics?
    @State private var currentLineIndex: Int?
    @State private var isImportingLRC = false
    @State private var isSearchingLyrics = false
    @State private var isDraggingOver = false

    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            if let track = playback.currentTrack {
                lyricsContent(track: track)
            } else {
                emptyState
            }
        }
        .background(Color.black.opacity(0.05))
        .onChange(of: playback.currentTrack) { _, newTrack in
            loadLyricsFor(track: newTrack)
        }
        .onChange(of: playback.currentTime) { _, _ in
            updateCurrentLine()
        }
        .onAppear {
            loadLyricsFor(track: playback.currentTrack)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Lyrics")
                .font(AppFonts.heading5)
                .foregroundColor(.primary)

            Spacer()

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

    // MARK: - Lyrics Content

    private func lyricsContent(track: Track) -> some View {
        Group {
            if let lyrics = lyrics, !lyrics.lines.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Spacer at top for better scrolling
                            Color.clear.frame(height: 30)

                            ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                                let isCurrent = currentLineIndex == index
                                let isPast = (currentLineIndex ?? -1) > index

                                lyricLine(
                                    text: line.text,
                                    isCurrent: isCurrent,
                                    isPast: isPast
                                )
                                .id(line.id)
                                .padding(.vertical, DesignTokens.Spacing.sm)
                                .onChange(of: isCurrent) { _, newValue in
                                    if newValue {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            proxy.scrollTo(line.id, anchor: .center)
                                        }
                                    }
                                }
                            }

                            // Spacer at bottom
                            Color.clear.frame(height: 30)
                        }
                    }
                }
            } else {
                noLyricsView
            }
        }
    }

    private func lyricLine(text: String, isCurrent: Bool, isPast: Bool) -> some View {
        Text(text)
            .font(isCurrent ? AppFonts.heading5 : AppFonts.captionLarge)
            .foregroundColor(
                isCurrent ? theme.currentTheme.primaryColor :
                isPast ? .secondary :
                .primary.opacity(0.6)
            )
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .animation(.easeInOut(duration: 0.25), value: isCurrent)
    }

    private var noLyricsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.quote")
                .font(AppFonts.displayLarge)
                .foregroundColor(.secondary.opacity(0.3))

            Text("No lyrics available")
                .font(AppFonts.captionLarge)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.quote")
                .font(AppFonts.displayLarge)
                .foregroundColor(.secondary.opacity(0.3))

            Text("Play a song to see lyrics")
                .font(AppFonts.captionLarge)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Methods

    private func loadLyricsFor(track: Track?) {
        guard let track = track,
              let trackId = track.trackId else {
            lyrics = nil
            currentLineIndex = nil
            return
        }

        Task {
            do {
                if let trackLyrics = try await database.getLyrics(forTrackId: trackId) {
                    await MainActor.run {
                        lyrics = Lyrics(lrcContent: trackLyrics.lrcContent)
                        updateCurrentLine()
                    }
                } else {
                    await MainActor.run {
                        lyrics = nil
                        currentLineIndex = nil
                    }
                }
            } catch {
                Logger.error("Failed to load lyrics: \(error)")
                await MainActor.run {
                    lyrics = nil
                    currentLineIndex = nil
                }
            }
        }
    }

    private func updateCurrentLine() {
        guard let lyrics = lyrics else {
            currentLineIndex = nil
            return
        }

        currentLineIndex = lyrics.currentLineIndex(at: playback.currentTime)
    }

}

// MARK: - Preview

#Preview {
    MiniLyricsView(onClose: {})
        .frame(width: 550, height: 300)
}
