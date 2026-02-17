//
//  GenresTabView.swift
//  HiFidelity
//
//  Created by Varun Rathod on 31/10/25.
//

import Observation
import SwiftUI

/// Genres tab view displaying all genres in a grid layout
struct GenresTabView: View {
    @Binding var selectedEntity: EntityType?
    let isVisible: Bool

    @Environment(DatabaseManager.self) var databaseManager
    @Bindable var theme = AppTheme.shared
    @Bindable var jellyfin = JellyfinSessionManager.shared

    @State private var genres: [Genre] = []
    @State private var filteredGenres: [Genre] = []
    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    @AppStorage("genresSortOptionId") private var sortOptionId: String = "name"
    @AppStorage("genresSortAscending") private var sortAscending: Bool = true
    @State private var jellyfinTracks: [Track] = []
    @State private var jellyfinNextStartIndex: Int = 0
    @State private var jellyfinHasMore: Bool = true
    @State private var jellyfinIsLoadingMore: Bool = false
    @State private var selectedSort = SortOption(id: "name", title: "Name", type: .alphabetical, ascending: true)
    @State private var selectedFilter: FilterOption?

    private let jellyfinPageSize = 200
    private let jellyfinTabKey = "genres"

    init(selectedEntity: Binding<EntityType?>, isVisible: Bool = true) {
        self._selectedEntity = selectedEntity
        self.isVisible = isVisible
    }

    private let sortOptions = [
        SortOption(id: "name", title: "Name", type: .alphabetical, ascending: true),
        SortOption(id: "tracks", title: "Track Count", type: .trackCount, ascending: false),
    ]

    private let filterOptions = [
        FilterOption(id: "popular", title: "Popular (20+ tracks)", predicate: "trackCount >= 20"),
        FilterOption(id: "medium", title: "Medium (10+ tracks)", predicate: "trackCount >= 10"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Content
            if isLoading {
                loadingView
            } else if filteredGenres.isEmpty {
                if genres.isEmpty {
                    emptyStateView(
                        icon: "guitars",
                        message: "No genres in library"
                    )
                } else {
                    emptyStateView(icon: "line.3.horizontal.decrease.circle", message: "No genres match your filter")
                }
            } else {
                LibraryGridScrollView(preset: DesignTokens.Grid.library) {
                    ForEach(Array(filteredGenres.enumerated()), id: \.element.id) { index, genre in
                        GenreCard(genre: genre) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedEntity = .genre(genre)
                            }
                        }
                    }

                    if jellyfin.isAuthenticated, jellyfinHasMore {
                        HStack {
                            Spacer()
                            if jellyfinIsLoadingMore {
                                ProgressView()
                            } else {
                                Button("Sync Jellyfin") {
                                    Task {
                                        await loadNextJellyfinPage()
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, DesignTokens.Spacing.md)
                    }
                }
                .refreshable {
                    await refreshJellyfinFromFirstPage()
                }
            }
        }
        .onChange(of: isVisible) { _, newValue in
            if newValue && !hasLoadedOnce {
                Task {
                    await loadGenres()
                    hasLoadedOnce = true
                }
            }
        }
        .onAppear {
            // Restore saved sort option
            if let savedOption = sortOptions.first(where: { $0.id == sortOptionId }) {
                selectedSort = SortOption(
                    id: savedOption.id,
                    title: savedOption.title,
                    type: savedOption.type,
                    ascending: sortAscending
                )
            }

            if isVisible && !hasLoadedOnce {
                Task {
                    await loadGenres()
                    hasLoadedOnce = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshLibraryData)) { _ in
            Task {
                await loadGenres()
            }
        }
        .onChange(of: selectedSort) { _, newSort in
            sortOptionId = newSort.id
            sortAscending = newSort.ascending
            applyFiltersAndSort()
        }
        .onChange(of: selectedFilter) { _, _ in
            applyFiltersAndSort()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()

            VStack(spacing: DesignTokens.Spacing.lg) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(theme.currentTheme.primaryColor)

            Text("Loading genres...")
                .font(AppFonts.bodySmall)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            // Count label
            Text("\(filteredGenres.count) genres")
                .font(AppFonts.labelMedium)
                .foregroundColor(.secondary)

            Spacer()

            // Sort and Filter dropdown
            GenreOptionsDropdown(
                selectedSort: $selectedSort,
                selectedFilter: $selectedFilter,
                sortOptions: sortOptions,
                filterOptions: filterOptions
            )
            .frame(width: DesignTokens.ControlHeight.sm)
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(height: DesignTokens.ControlHeight.xl)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func loadGenres() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let localGenres = try await databaseManager.getAllGenres()
            var remoteGenres: [Genre] = []

            if jellyfin.isAuthenticated {
                remoteGenres = try await databaseManager.getRemoteGenres()
                jellyfinHasMore = true
                jellyfinIsLoadingMore = false
                Task {
                    await jellyfin.syncRemoteIndex(forceRefresh: false)
                }
            } else {
                jellyfinTracks = []
                jellyfinNextStartIndex = 0
                jellyfinHasMore = false
                jellyfinIsLoadingMore = false
            }

            genres = mergeGenres(local: localGenres, remote: remoteGenres)
            applyFiltersAndSort()
        } catch {
            Logger.error("Failed to load genres: \(error)")
        }
    }

    private func loadNextJellyfinPage() async {
        guard jellyfin.isAuthenticated,
              !jellyfinIsLoadingMore else {
            return
        }

        jellyfinIsLoadingMore = true
        defer { jellyfinIsLoadingMore = false }

        await jellyfin.syncRemoteIndex(forceRefresh: true)
        await loadGenres()
    }

    private func refreshJellyfinFromFirstPage() async {
        if jellyfin.isAuthenticated {
            await jellyfin.syncRemoteIndex(forceRefresh: true)
        }
        await loadGenres()
    }

    private func applyFiltersAndSort() {
        var result = genres

        // Apply track count filters
        if let filter = selectedFilter {
            switch filter.id {
            case "popular":
                result = result.filter { $0.trackCount >= 20 }

            case "medium":
                result = result.filter { $0.trackCount >= 10 }

            default:
                break
            }
        }

        // Apply sort
        switch selectedSort.type {
        case .alphabetical:
            result.sort { $0.name.localizedCompare($1.name) == .orderedAscending }

        case .trackCount:
            result.sort { $0.trackCount > $1.trackCount }

        default:
            break
        }

        if !selectedSort.ascending {
            result.reverse()
        }

        filteredGenres = result
    }

    private func mergeGenres(local: [Genre], remote: [Genre]) -> [Genre] {
        var result: [Genre] = local
        let localNames = Set(local.map { $0.name.lowercased() })

        for genre in remote where !localNames.contains(genre.name.lowercased()) {
            result.append(genre)
        }

        return result
    }
}

// MARK: - Genre Options Dropdown

private struct GenreOptionsDropdown: View {
    @Binding var selectedSort: SortOption
    @Binding var selectedFilter: FilterOption?
    let sortOptions: [SortOption]
    let filterOptions: [FilterOption]

    @Bindable private var theme = AppTheme.shared

    var body: some View {
        Menu {
            Section("Sort by") {
                ForEach(sortOptions) { option in
                    Button {
                        selectedSort = option
                    } label: {
                        HStack {
                            Text(option.title)
                            if selectedSort.id == option.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Section("Sort order") {
                Button {
                    selectedSort = SortOption(
                        id: selectedSort.id,
                        title: selectedSort.title,
                        type: selectedSort.type,
                        ascending: true
                    )
                } label: {
                    HStack {
                        Text("Ascending")
                        if selectedSort.ascending {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button {
                    selectedSort = SortOption(
                        id: selectedSort.id,
                        title: selectedSort.title,
                        type: selectedSort.type,
                        ascending: false
                    )
                } label: {
                    HStack {
                        Text("Descending")
                        if !selectedSort.ascending {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Section("Filter") {
                ForEach(filterOptions) { filter in
                    Button {
                        selectedFilter = (selectedFilter == filter) ? nil : filter
                    } label: {
                        HStack {
                            Text(filter.title)
                            if selectedFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                if selectedFilter != nil {
                    Button("Clear Filter") {
                        selectedFilter = nil
                    }
                }
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xsPlus) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(AppFonts.labelLarge)
                if selectedFilter != nil {
                    Image(systemName: "circle.fill")
                        .font(AppFonts.captionSmall)
                        .foregroundColor(theme.currentTheme.primaryColor)
                }
            }
            .foregroundColor(selectedFilter != nil ? theme.currentTheme.primaryColor : .secondary)
            .frame(width: DesignTokens.ControlHeight.sm, height: DesignTokens.ControlHeight.sm)
            .background(
                Circle()
                    .fill(selectedFilter != nil ? theme.currentTheme.primaryColor.opacity(0.15) : Color.clear)
            )
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
    }
}
