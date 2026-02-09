//
//  LyricsPanel.swift
//  HiFidelity
//
//  Karaoke-style synchronized lyrics with LRC file support
//

import Observation
import SwiftUI
import UniformTypeIdentifiers

/// Complete karaoke-style lyrics panel with LRC support
struct LyricsPanel: View {
    @Bindable var playback = PlaybackController.shared
    @Bindable var theme = AppTheme.shared
    @Bindable var database = DatabaseManager.shared

    @State var lyrics: Lyrics?
    @State var currentLineIndex: Int?
    @State var isImportingLRC = false
    @State var showImportSuccess = false
    @State var isDraggingOver = false
    @State var isAppActive = true

    // Online lyrics search
    @State var isSearchingLyrics = false
    @State var showSearchResults = false
    @State var searchResults: [LyricsSearchResult] = []
    @State var searchError: String?
    @State var isLoadingSearch = false

    // Timer for updating current line
    @State var updateTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Header with actions
            header

            Divider()

            // Content
            if let track = playback.currentTrack {
                lyricsContent(track: track)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            if isDraggingOver {
                dragOverlay
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            handleDrop(providers: providers)
        }
        .fileImporter(
            isPresented: $isImportingLRC,
            allowedContentTypes: [UTType(filenameExtension: "lrc")!],
            allowsMultipleSelection: false
        ) { result in
            handleLRCImport(result)
        }
        .alert("Lyrics Imported", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("LRC file has been imported successfully")
        }
        .sheet(isPresented: $showSearchResults) {
            searchResultsView
        }
        .onChange(of: playback.currentTrack) { _, newTrack in
            loadLyricsFor(track: newTrack)
        }
        .onChange(of: playback.currentTime) { _, _ in
            if isAppActive {
                updateCurrentLine()
            }
        }
        .onAppear {
            loadLyricsFor(track: playback.currentTrack)
            setupLifecycleObservers()
        }
        .onDisappear {
            removeLifecycleObservers()
        }
        .textSelection(.enabled)
    }
}

extension LyricsPanel {
    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Lyrics")
                .font(AppFonts.heading4)
                .foregroundColor(.primary)
            .frame(height: DesignTokens.ControlHeight.xs)

            Spacer()

            if playback.currentTrack != nil {
                Menu {
                    Button(action: searchOnlineLyrics) {
                        Label("Search Online", systemImage: "magnifyingglass")
                    }
                    .disabled(isLoadingSearch || lyrics != nil)

                    Button(action: { isImportingLRC = true }) {
                        Label("Import LRC File", systemImage: "doc.badge.plus")
                    }
                    .disabled(lyrics != nil)

                    if lyrics != nil {
                        Divider()

                        Button(action: exportLyrics) {
                            Label("Export LRC File", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive, action: removeLyrics) {
                            Label("Remove Lyrics", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(AppFonts.bodyLarge)
                        .foregroundColor(.secondary)
                        .frame(width: DesignTokens.ControlHeight.xs, height: DesignTokens.ControlHeight.xs)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .frame(width: DesignTokens.ControlHeight.xs)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - Lyrics Content

    private func lyricsContent(track: Track) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 32) {
                    // Track info
                    trackInfo(track: track)

                    // Lyrics display
                    if let lyrics = lyrics, !lyrics.lines.isEmpty {
                        karaokeLyrics(lyrics: lyrics, proxy: proxy)
                    } else {
                        noLyricsView
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DesignTokens.Spacing.xxxl)
                .padding(.bottom, DesignTokens.ControlHeight.playbackBar)
            }
        }
    }

    private func trackInfo(track: Track) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Album artwork
            TrackArtworkView(
                track: track,
                size: DesignTokens.Size.Artwork.mdPlus,
                cornerRadius: DesignTokens.CornerRadius.lg
            )
                .tokenShadow(DesignTokens.Shadow.level1)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(track.title)
                    .font(AppFonts.heading3)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(track.artist)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, DesignTokens.Spacing.xxxxl)
    }

    private func karaokeLyrics(lyrics: Lyrics, proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                let isCurrent = currentLineIndex == index
                let isPast = (currentLineIndex ?? -1) > index

                lyricLine(
                    text: line.text,
                    isCurrent: isCurrent,
                    isPast: isPast
                )
                .id(line.id)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(
                    isCurrent ?
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                        .fill(theme.currentTheme.primaryColor.opacity(0.1))
                        .padding(.horizontal, DesignTokens.Spacing.negativeLg)
                    : nil
                )
                .onChange(of: isCurrent) { _, newValue in
                    if newValue {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(line.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    private func lyricLine(text: String, isCurrent: Bool, isPast: Bool) -> some View {
        Text(text)
            .font(isCurrent ? AppFonts.heading2 : AppFonts.bodyLarge)
            .foregroundColor(
                isCurrent ? theme.currentTheme.primaryColor :
                isPast ? .secondary :
                .primary.opacity(0.6)
            )
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .animation(.easeInOut(duration: 0.3), value: isCurrent)
    }

    private var noLyricsView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "text.quote")
                .font(AppFonts.displayLarge)
                .foregroundColor(.secondary.opacity(0.2))

            Text("No lyrics available")
                .font(AppFonts.bodyLarge)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: searchOnlineLyrics) {
                if isLoadingSearch {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(minWidth: DesignTokens.Size.Button.minWidth)
                        .frame(height: DesignTokens.ControlHeight.xs)
                } else {
                    Label("Search Online", systemImage: "magnifyingglass")
                        .font(AppFonts.buttonMedium)
                        .padding(DesignTokens.Spacing.xs)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.currentTheme.primaryColor)
            .disabled(isLoadingSearch)
            .frame(minWidth: DesignTokens.Size.Button.minWidth)

            Text("OR")
                .font(AppFonts.bodyLarge)
                .foregroundColor(.secondary)

            Button(action: { isImportingLRC = true }) {
                Label("Import LRC File", systemImage: "doc.badge.plus")
                    .font(AppFonts.buttonMedium)
                    .padding(DesignTokens.Spacing.xs)
            }
            .buttonStyle(.bordered)
            .frame(minWidth: DesignTokens.Size.Button.minWidth)

            Text("or drag and drop an LRC file here")
                .font(AppFonts.captionLarge)
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.top, DesignTokens.Spacing.xs)

            if let error = searchError {
                Text(error)
                    .font(AppFonts.captionLarge)
                    .foregroundColor(.red)
                    .padding(.top, DesignTokens.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.xxxxxl)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Image(systemName: "text.quote")
                .font(AppFonts.displayLarge)
                .foregroundColor(.secondary.opacity(0.2))

            Text("Play a song to see the lyrics here.")
                .font(AppFonts.bodyLarge)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xxxxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, DesignTokens.ControlHeight.playbackBar)
    }
}
