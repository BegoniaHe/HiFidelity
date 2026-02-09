//  LyricsPanel+Helpers.swift
//  HiFidelity
//
//  Helpers and import/export for LyricsPanel
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension LyricsPanel {
    // MARK: - Drag Overlay

    var dragOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)

            VStack(spacing: 20) {
                Image(systemName: "arrow.down.doc")
                    .font(AppFonts.placeholder(size: 64, weight: .light))
                    .foregroundColor(theme.currentTheme.primaryColor)

                Text("Drop LRC file here")
                    .font(AppFonts.heading2)
                    .foregroundColor(.primary)

                Text("Release to import lyrics")
                    .font(AppFonts.bodySmall)
                    .foregroundColor(.secondary)
            }
            .padding(DesignTokens.Spacing.xxxxl)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .tokenShadow(DesignTokens.Shadow.level3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.currentTheme.primaryColor, lineWidth: 3)
                    .padding(DesignTokens.Spacing.hairline)
            )
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: isDraggingOver)
    }

    // MARK: - Helper Methods

    func loadLyricsFor(track: Track?) {
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

    func updateCurrentLine() {
        guard let lyrics = lyrics else {
            currentLineIndex = nil
            return
        }

        currentLineIndex = lyrics.currentLineIndex(at: playback.currentTime)
    }

    func syncToCurrentPosition() {
        // Force update to current playback position
        updateCurrentLine()
        Logger.info("Lyrics synced to current playback position")
    }

    func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.isAppActive = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.isAppActive = false
            }
        }
    }

    func removeLifecycleObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard playback.currentTrack != nil else {
            Logger.warning("Cannot import lyrics: no track currently playing")
            return false
        }

        guard let provider = providers.first else {
            return false
        }

        // Check if provider has file URL
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { urlData, error in
                if let error = error {
                    Logger.error("Failed to load dropped item: \(error)")
                    return
                }

                if let urlData = urlData as? Data,
                   let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                    // Check if it's an LRC file
                    guard url.pathExtension.lowercased() == "lrc" else {
                        Logger.warning("Dropped file is not an LRC file: \(url.lastPathComponent)")
                        return
                    }

                    // Import the file
                    DispatchQueue.main.async {
                        self.importLRCFile(from: url)
                    }
                }
            }
            return true
        }

        return false
    }

    func importLRCFile(from url: URL) {
        guard let track = playback.currentTrack else { return }

        // Try to access security-scoped resource (may not be needed for drag-and-drop)
        let didStartAccessing = url.startAccessingSecurityScopedResource()

        // Ensure we stop accessing when done (only if we successfully started)
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let lrcContent = try String(contentsOf: url, encoding: .utf8)

            // Parse to validate
            let parsedLyrics = Lyrics(lrcContent: lrcContent)
            guard !parsedLyrics.lines.isEmpty else {
                Logger.error("LRC file is empty or invalid")
                return
            }

            // Save to database
            Task {
                do {
                    try await saveLyricsToDatabase(track: track, lrcContent: lrcContent)

                    await MainActor.run {
                        lyrics = parsedLyrics
                        showImportSuccess = true
                        Logger.info("LRC file imported successfully: \(parsedLyrics.lines.count) lines from \(url.lastPathComponent)")
                    }
                } catch {
                    Logger.error("Failed to save lyrics to database: \(error)")
                }
            }
        } catch {
            Logger.error("Failed to read LRC file '\(url.lastPathComponent)': \(error)")
        }
    }

    func handleLRCImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importLRCFile(from: url)

        case .failure(let error):
            Logger.error("LRC import failed: \(error)")
        }
    }

    func saveLyricsToDatabase(track: Track, lrcContent: String) async throws {
        guard let trackId = track.trackId else {
            throw DatabaseError.trackNotFound(id: 0)
        }

        // Check if lyrics already exist for this track
        if let existing = try await database.getLyrics(forTrackId: trackId) {
            // Update existing lyrics
            try await database.updateLyricsContent(id: existing.id!, lrcContent: lrcContent)
        } else {
            // Insert new lyrics
            _ = try await database.insertLyrics(
                trackId: trackId,
                lrcContent: lrcContent,
                source: "user"
            )
        }
    }

    func exportLyrics() {
        guard let lyrics = lyrics,
              let track = playback.currentTrack else { return }

        let lrcContent = lyrics.toLRC()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(track.title) - \(track.artist).lrc"
        panel.allowedContentTypes = [UTType(filenameExtension: "lrc")!]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                // Request access to security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    Logger.error("Failed to access security-scoped resource for export: \(url.path)")
                    return
                }

                defer {
                    url.stopAccessingSecurityScopedResource()
                }

                do {
                    try lrcContent.write(to: url, atomically: true, encoding: .utf8)
                    Logger.info("LRC file exported successfully to: \(url.path)")
                } catch {
                    Logger.error("Failed to export LRC file: \(error)")
                }
            }
        }
    }

    func removeLyrics() {
        guard let track = playback.currentTrack,
              let trackId = track.trackId else { return }

        Task {
            do {
                try await database.deleteAllLyrics(forTrackId: trackId)

                await MainActor.run {
                    lyrics = nil
                    currentLineIndex = nil
                    Logger.info("Lyrics removed")
                }
            } catch {
                Logger.error("Failed to remove lyrics: \(error)")
            }
        }
    }

    // MARK: - Online Lyrics Search

    func searchOnlineLyrics() {
        guard let track = playback.currentTrack else { return }

        searchError = nil
        isLoadingSearch = true

        Task {
            do {
                let results = try await LyricsService.shared.searchLyrics(
                    trackName: track.title,
                    artistName: track.artist,
                    albumName: track.album,
                    duration: Int(track.duration)
                )

                await MainActor.run {
                    isLoadingSearch = false

                    if results.isEmpty {
                        searchError = "No lyrics found for this track"
                    } else if results.count == 1, let result = results.first, result.hasSyncedLyrics {
                        // Auto-import if only one result with synced lyrics
                        importSearchResult(result)
                    } else {
                        // Show results for user selection
                        searchResults = results
                        showSearchResults = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingSearch = false
                    searchError = error.localizedDescription
                    Logger.error("Lyrics search failed: \(error)")
                }
            }
        }
    }

    func importSearchResult(_ result: LyricsSearchResult) {
        guard let track = playback.currentTrack,
              let lrcContent = result.lrcContent else { return }

        // Parse to validate
        let parsedLyrics = Lyrics(lrcContent: lrcContent)
        guard !parsedLyrics.lines.isEmpty else {
            searchError = "Failed to parse lyrics"
            return
        }

        Task {
            do {
                try await saveLyricsToDatabase(track: track, lrcContent: lrcContent)

                await MainActor.run {
                    lyrics = parsedLyrics
                    searchError = nil
                    showSearchResults = false
                    showImportSuccess = true
                    Logger.info("Online lyrics imported: \(parsedLyrics.lines.count) lines")
                }
            } catch {
                await MainActor.run {
                    searchError = "Failed to save lyrics"
                    Logger.error("Failed to save online lyrics: \(error)")
                }
            }
        }
    }

    // MARK: - Search Results View

    var searchResultsView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                        Text("Search Results")
                            .font(AppFonts.heading3)

                Spacer()

                Button(action: { showSearchResults = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(AppFonts.bodyLarge)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Results list
            if searchResults.isEmpty {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Image(systemName: "magnifyingglass")
                        .font(AppFonts.displayLarge)
                        .foregroundColor(.secondary.opacity(0.3))

                    Text("No results found")
                        .font(AppFonts.heading4)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(searchResults) { result in
                            searchResultRow(result: result)
                        }
                    }
                }
            }
        }
        .frame(
            width: DesignTokens.Size.Window.lyricsSearchWidth,
            height: DesignTokens.Size.Window.lyricsSearchHeight
        )
        .background(Color(nsColor: .windowBackgroundColor))
    }

    func searchResultRow(result: LyricsSearchResult) -> some View {
        Button(action: {
            importSearchResult(result)
        }) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(result.trackName)
                            .font(AppFonts.heading5)
                            .foregroundColor(.primary)

                        Text(result.artistName)
                            .font(AppFonts.bodySmall)
                            .foregroundColor(.secondary)

                        if let album = result.albumName {
                            Text(album)
                                .font(AppFonts.captionLarge)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                        if result.hasSyncedLyrics {
                            HStack(spacing: DesignTokens.Spacing.xs) {
                                Image(systemName: "waveform")
                                    .font(AppFonts.captionSmall)
                                Text("Synced")
                                    .font(AppFonts.labelSmall)
                            }
                            .foregroundColor(theme.currentTheme.primaryColor)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(theme.currentTheme.primaryColor.opacity(0.1))
                            )
                        } else if result.plainLyrics != nil {
                            Text("Plain")
                                .font(AppFonts.captionMedium)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                                .background(
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.1))
                                )
                        }

                        Text(formatDuration(result.duration))
                            .font(AppFonts.captionLarge)
                            .foregroundColor(.secondary)
                    }
                }

                if result.instrumental {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "music.note")
                            .font(AppFonts.captionSmall)
                        Text("Instrumental")
                            .font(AppFonts.captionMedium)
                    }
                    .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: DesignTokens.Spacing.hairline),
            alignment: .bottom
        )
    }

    func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
