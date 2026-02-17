//
//  SearchResultsView.swift
//  HiFidelity
//
//  Search results view with categorized results
//

import Observation
import SwiftUI

struct SearchResultsView: View {
    let searchQuery: String
    @Binding var selectedEntity: EntityType?

    @Environment(DatabaseManager.self) var databaseManager
    @Bindable var theme = AppTheme.shared
    @Bindable var playback = PlaybackController.shared
    @Bindable var jellyfin = JellyfinSessionManager.shared

    @State private var results = DatabaseManager.SearchResults()
    @State private var isLoading = false
    @State private var selectedCategory: SearchCategory = .all
    @State private var searchMode: DatabaseManager.SearchMode = .and

    var body: some View {
        VStack(spacing: 0) {
            // Search header with mode toggle
            searchHeader

            Divider()

            // Category filters
            categoryFilters

            Divider()

            // Results content
            if isLoading {
                loadingView
            } else if results.isEmpty {
                emptyStateView
            } else {
                resultsContent
            }
        }
        .textSelection(.enabled)
        .task(id: searchQuery) {
            await performSearch()
        }
        .onChange(of: searchMode) { _, _ in
            // Already handled in the picker onChange above, but keeping this
            // for consistency if searchMode changes from elsewhere
        }
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text("Search Results")
                        .font(AppFonts.heading2)

                    Image(systemName: "info.circle")
                        .font(AppFonts.labelLarge)
                        .foregroundColor(.secondary)
                        .help(searchTips)
                }

                if !results.isEmpty {
                    Text("\(results.totalCount) results for \"\(searchQuery)\"")
                        .font(AppFonts.bodySmall)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Search mode toggle
            Picker("", selection: $searchMode) {
                Text("Match All").tag(DatabaseManager.SearchMode.and)
                Text("Match Any").tag(DatabaseManager.SearchMode.or)
            }
            .pickerStyle(.segmented)
            .frame(width: DesignTokens.Size.Form.searchModePickerWidth)
            .help(searchMode == .and ?
                  "Match ALL words (exact search)" :
                  "Match ANY word (broader results)")
            .onChange(of: searchMode) { _, _ in
                Task {
                    await performSearch()
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    private var searchTips: String {
        "Search tips:\n" +
        "• Results ranked by relevance (title > artist > album)\n" +
        "• Use quotes for exact phrases: \"dark side\"\n" +
        "• Prefix matching: \"beat\" matches \"beatles\"\n" +
        "• Acronyms: \"BYOB\" matches \"B.Y.O.B\"\n" +
        "• Combine terms: \"BYOB system\" for better results\n" +
        "• Match All: all words must match\n" +
        "• Match Any: broader results"
    }

    // MARK: - Category Filters

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(SearchCategory.allCases) { category in
                    CategoryButton(
                        category: category,
                        count: categoryCount(category),
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
    }

    // MARK: - Results Content

    private var resultsContent: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.xxl, pinnedViews: []) {
                    if selectedCategory == .all || selectedCategory == .tracks {
                        if !results.tracks.isEmpty {
                            resultSection(
                                title: "Tracks",
                                icon: "music.note",
                                count: results.tracks.count
                            ) {
                                tracksSection
                            }
                        }
                    }

                    if selectedCategory == .all || selectedCategory == .albums {
                        if !results.albums.isEmpty {
                            resultSection(
                                title: "Albums",
                                icon: "square.stack",
                                count: results.albums.count
                            ) {
                                albumsSection(availableWidth: proxy.size.width)
                            }
                        }
                    }

                    if selectedCategory == .all || selectedCategory == .artists {
                        if !results.artists.isEmpty {
                            resultSection(
                                title: "Artists",
                                icon: "person.2",
                                count: results.artists.count
                            ) {
                                artistsSection(availableWidth: proxy.size.width)
                            }
                        }
                    }

                    if selectedCategory == .all || selectedCategory == .genres {
                        if !results.genres.isEmpty {
                            resultSection(
                                title: "Genres",
                                icon: "guitars",
                                count: results.genres.count
                            ) {
                                genresSection(availableWidth: proxy.size.width)
                            }
                        }
                    }

                    if selectedCategory == .all || selectedCategory == .playlists {
                        if !results.playlists.isEmpty {
                            resultSection(
                                title: "Playlists",
                                icon: "music.note.list",
                                count: results.playlists.count
                            ) {
                                playlistsSection(availableWidth: proxy.size.width)
                            }
                        }
                    }
                }
                .padding(DesignTokens.Spacing.xl)
            }
        }
        .id(selectedCategory)
    }

    // MARK: - Result Sections

    @ViewBuilder
    private func resultSection<Content: View>(
        title: String,
        icon: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(AppFonts.heading4)
                    .foregroundColor(theme.currentTheme.primaryColor)

                Text(title)
                    .font(AppFonts.heading3)

                Text("(\(count))")
                    .font(AppFonts.bodySmall)
                    .foregroundColor(.secondary)
            }

            content()
        }
    }

    private var tracksSection: some View {
        let tracksToShow = selectedCategory == .all ? Array(results.tracks.prefix(10)) : results.tracks

        return VStack(spacing: 0) {
            ForEach(tracksToShow) { track in
                TrackSearchRow(track: track) {
                    playback.playTracks([track], startingAt: 0)
                }

                if track.id != tracksToShow.last?.id {
                    Divider()
                        .padding(.leading, DesignTokens.Spacing.xxl)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func albumsSection(availableWidth: CGFloat) -> some View {
        let albumsToShow = selectedCategory == .all ? Array(results.albums.prefix(8)) : results.albums

        return LibraryGrid(availableWidth: availableWidth, preset: DesignTokens.Grid.library) {
            ForEach(albumsToShow) { album in
                AlbumCard(album: album) {
                    selectedEntity = .album(album)
                }
            }
        }
    }

    private func artistsSection(availableWidth: CGFloat) -> some View {
        let artistsToShow = selectedCategory == .all ? Array(results.artists.prefix(8)) : results.artists

        return LibraryGrid(availableWidth: availableWidth, preset: DesignTokens.Grid.library) {
            ForEach(artistsToShow) { artist in
                ArtistCard(artist: artist) {
                    selectedEntity = .artist(artist)
                }
            }
        }
    }

    private func genresSection(availableWidth: CGFloat) -> some View {
        let genresToShow = selectedCategory == .all ? Array(results.genres.prefix(8)) : results.genres

        return LibraryGrid(availableWidth: availableWidth, preset: DesignTokens.Grid.library) {
            ForEach(genresToShow) { genre in
                GenreCard(genre: genre) {
                    selectedEntity = .genre(genre)
                }
            }
        }
    }

    private func playlistsSection(availableWidth: CGFloat) -> some View {
        let playlistsToShow = selectedCategory == .all ? Array(results.playlists.prefix(8)) : results.playlists

        return LibraryGrid(availableWidth: availableWidth, preset: DesignTokens.Grid.library) {
            ForEach(playlistsToShow) { playlist in
                PlaylistSearchCard(playlist: playlist) {
                    let playlistItem = PlaylistItem(
                        id: "user_\(playlist.id ?? 0)",
                        name: playlist.name,
                        isPinned: playlist.isFavorite,
                        type: .user(playlist)
                    )
                    selectedEntity = .playlist(playlistItem)
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(theme.currentTheme.primaryColor)

            Text("Searching...")
                .font(AppFonts.bodySmall)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(AppFonts.displayLarge)
                .foregroundColor(.secondary.opacity(0.3))

            Text("No results found")
                .font(AppFonts.heading3)

            Text("Try a different search term")
                .font(AppFonts.bodySmall)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Methods

    private func categoryCount(_ category: SearchCategory) -> Int {
        switch category {
        case .all:
            return results.totalCount

        case .tracks:
            return results.tracks.count

        case .albums:
            return results.albums.count

        case .artists:
            return results.artists.count

        case .genres:
            return results.genres.count

        case .playlists:
            return results.playlists.count
        }
    }

    private func performSearch() async {
        guard !searchQuery.isEmpty else {
            results = DatabaseManager.SearchResults()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Use selected search mode
            results = try await databaseManager.search(query: searchQuery, mode: searchMode)

            if jellyfin.isAuthenticated {
                let remoteTracks = await jellyfin.searchTracks(query: searchQuery, limit: 100)
                if !remoteTracks.isEmpty {
                    results.tracks = mergeTracks(local: results.tracks, remote: remoteTracks)
                }
            }

            Logger.info("Search completed (\(searchMode == .and ? "AND" : "OR") mode): \(results.totalCount) total results")
        } catch {
            Logger.error("Search failed: \(error)")

            results = DatabaseManager.SearchResults()
        }
    }

    private func mergeTracks(local: [Track], remote: [Track]) -> [Track] {
        var merged = local
        var seenRemoteItemIds = Set(local.compactMap { $0.remoteItemId })
        var seenURLs = Set(local.map { $0.url.absoluteString })

        for track in remote {
            if let remoteItemId = track.remoteItemId, seenRemoteItemIds.contains(remoteItemId) {
                continue
            }

            let urlString = track.url.absoluteString
            if seenURLs.contains(urlString) {
                continue
            }

            merged.append(track)
            if let remoteItemId = track.remoteItemId {
                seenRemoteItemIds.insert(remoteItemId)
            }
            seenURLs.insert(urlString)
        }

        return merged
    }
}

// MARK: - Track Search Row

struct TrackSearchRow: View {
    let track: Track
    let onPlay: () -> Void

    @Bindable var theme = AppTheme.shared
    @Bindable var playback = PlaybackController.shared
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Artwork
            TrackArtworkView(track: track, size: 48, cornerRadius: DesignTokens.CornerRadius.xs)

            // Track info
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(track.title)
                    .font(AppFonts.labelLarge)
                    .lineLimit(1)

                Text("\(track.artist) • \(track.album)")
                    .font(AppFonts.captionLarge)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Duration
            Text(formatDuration(track.duration))
                .font(AppFonts.captionLarge)
                .foregroundColor(.secondary)
                .monospacedDigit()

            // Play button
            if isHovered {
                Button {
                    onPlay()
                } label: {
                    Image(systemName: "play.fill")
                        .font(AppFonts.labelLarge)
                        .foregroundColor(.white)
                        .frame(width: DesignTokens.ControlHeight.sm, height: DesignTokens.ControlHeight.sm)
                        .background(
                            Circle()
                                .fill(theme.currentTheme.primaryColor)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .contentShape(Rectangle())
        .textSelection(.enabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onPlay()
        }
        .contextMenu {
            TrackContextMenu(track: track)
        }
    }
}

// MARK: - Playlist Search Card

struct PlaylistSearchCard: View {
    let playlist: Playlist
    let onSelect: () -> Void

    @Bindable var theme = AppTheme.shared
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Artwork placeholder
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.currentTheme.primaryColor.opacity(0.3),
                                theme.currentTheme.primaryColor.opacity(0.1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "music.note.list")
                    .font(AppFonts.displayLarge)
                    .foregroundColor(theme.currentTheme.primaryColor)
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(playlist.name)
                    .font(AppFonts.heading5)
                    .lineLimit(1)

                Text("\(playlist.trackCount) tracks")
                    .font(AppFonts.captionLarge)
                    .foregroundColor(.secondary)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .fill(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let category: SearchCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @Bindable var theme = AppTheme.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(category.title)
                    .font(AppFonts.labelMedium)

                if count > 0 {
                    Text("\(count)")
                        .font(AppFonts.labelSmall)
                        .foregroundColor(isSelected ? .white : .secondary)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? theme.currentTheme.primaryColor : Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Category

enum SearchCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case tracks = "Tracks"
    case albums = "Albums"
    case artists = "Artists"
    case genres = "Genres"
    case playlists = "Playlists"

    var id: String { rawValue }

    var title: String { rawValue }
}

// MARK: - Helper Function

private func formatDuration(_ duration: Double) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%d:%02d", minutes, seconds)
}
