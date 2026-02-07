//
//  LyricsPanel.swift
//  HiFidelity
//
//  Karaoke-style synchronized lyrics with LRC file support
//

import SwiftUI
import UniformTypeIdentifiers

/// Complete karaoke-style lyrics panel with LRC support
struct LyricsPanel: View {
    @ObservedObject var playback = PlaybackController.shared
    @ObservedObject var theme = AppTheme.shared
    @ObservedObject var database = DatabaseManager.shared

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
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .frame(height: 28)

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
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .frame(width: 28)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)

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
                .padding(.horizontal, 32)
                .padding(.bottom, 90)
            }
        }
    }

    private func trackInfo(track: Track) -> some View {
        VStack(spacing: 12) {
            // Album artwork
            TrackArtworkView(track: track, size: 120, cornerRadius: 12)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

            VStack(spacing: 4) {
                Text(track.title)
                    .font(AppFonts.heading3)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(track.artist)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 40)
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
                .padding(.vertical, 12)
                .background(
                    isCurrent ?
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.currentTheme.primaryColor.opacity(0.1))
                        .padding(.horizontal, -16)
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
        .padding(.vertical, 16)
    }

    private func lyricLine(text: String, isCurrent: Bool, isPast: Bool) -> some View {
        Text(text)
            .font(isCurrent ? .system(size: 20, weight: .semibold) : .system(size: 16))
            .foregroundColor(
                isCurrent ? theme.currentTheme.primaryColor :
                isPast ? .secondary :
                .primary.opacity(0.6)
            )
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .animation(.easeInOut(duration: 0.3), value: isCurrent)
    }

    private var noLyricsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.quote")
                .font(.system(size: 52))
                .foregroundColor(.secondary.opacity(0.2))

            Text("No lyrics available")
                .font(AppFonts.bodyLarge)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: searchOnlineLyrics) {
                if isLoadingSearch {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(minWidth: 140)
                        .frame(height: 28)
                } else {
                    Label("Search Online", systemImage: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .padding(4)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.currentTheme.primaryColor)
            .disabled(isLoadingSearch)
            .frame(minWidth: 140)

            Text("OR")
                .font(AppFonts.bodyLarge)
                .foregroundColor(.secondary)

            Button(action: { isImportingLRC = true }) {
                Label("Import LRC File", systemImage: "doc.badge.plus")
                    .font(.system(size: 14, weight: .medium))
                    .padding(4)
            }
            .buttonStyle(.bordered)
            .frame(minWidth: 140)

            Text("or drag and drop an LRC file here")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.top, 4)

            if let error = searchError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.quote")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.2))

            Text("Play a song to see the lyrics here.")
                .font(AppFonts.bodyLarge)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 90)
    }

}
