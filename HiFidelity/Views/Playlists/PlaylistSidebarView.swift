//
//  PlaylistSidebarView.swift
//  HiFidelity
//
//  Created by Varun Rathod on 31/10/25.
//

import AppKit
import Observation
import SwiftUI

/// Playlist sidebar showing pinned and user playlists
struct PlaylistSidebarView: View {
    @Environment(DatabaseManager.self) private var databaseManager
    @Bindable var theme = AppTheme.shared
    @Binding var selectedTab: NavigationTab
    @Binding var selectedEntity: EntityType?

    @State private var viewModel = PlaylistSidebarViewModel()
    @State private var searchText = ""
    @State private var showCreatePlaylist = false
    @AppStorage("playlistSortOption") private var sortOptionId: String = "name"
    @AppStorage("playlistSortAscending") private var sortAscending = true
    @State private var sortOption: PlaylistSortOption = .name
    @State private var isSelectionMode = false
    @State private var selectedPlaylistIds: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // Playlists header
            playlistsHeader

            Divider()
                .opacity(0)  // invisible

            // Search bar
            searchBar

            Divider()

            // Playlist items
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, DesignTokens.ControlHeight.playbackBar)
            } else if viewModel.allPlaylists.isEmpty {
                emptyStateView
                    .padding(.bottom, DesignTokens.ControlHeight.playbackBar)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        // Smart Playlists Section
                        if !viewModel.smartPlaylists.isEmpty {
                            Section {
                                ForEach(viewModel.smartPlaylists) { playlist in
                                    playlistRow(playlist)
                                }
                            } header: {
                                sectionHeader(title: "Smart Playlists")
                            }
                        }

                        // Pinned Playlists Section
                        if !viewModel.pinnedPlaylists.isEmpty {
                            Section {
                                ForEach(viewModel.pinnedPlaylists) { playlist in
                                    playlistRow(playlist)
                                }
                            } header: {
                                sectionHeader(title: "Pinned")
                            }
                        }

                        // All Playlists Section
                        if !viewModel.userPlaylists.isEmpty {
                            Section {
                                ForEach(viewModel.userPlaylists) { playlist in
                                    playlistRow(playlist)
                                }
                            } header: {
                                sectionHeader(title: "Playlists")
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.top, DesignTokens.Spacing.sm)
                }
                .padding(.bottom, DesignTokens.ControlHeight.playbackBar)
            }
        }
        .background(Color.black.opacity(0.02))
        .task {
            await viewModel.loadPlaylists()
        }
        .onAppear {
            // Restore saved sort option
            if let savedOption = PlaylistSortOption(rawValue: sortOptionId) {
                sortOption = savedOption
            }
            // Apply initial sort
            viewModel.sortPlaylists(by: sortOption, ascending: sortAscending)
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.filterPlaylists(query: newValue)
        }
        .onChange(of: sortOption.rawValue) { _, newValue in
            sortOptionId = newValue
            viewModel.sortPlaylists(by: sortOption, ascending: sortAscending)
        }
        .onChange(of: sortAscending) { _, _ in
            viewModel.sortPlaylists(by: sortOption, ascending: sortAscending)
        }
        .sheet(isPresented: $showCreatePlaylist) {
            CreatePlaylistView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .playlistsDidChange)) { _ in
            Task {
                await viewModel.loadPlaylists()
                viewModel.sortPlaylists(by: sortOption, ascending: sortAscending)
            }
        }
    }
}

extension PlaylistSidebarView {
    // MARK: - Header

    private var playlistsHeader: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            if isSelectionMode {
                // Selection mode UI
                Button {
                    isSelectionMode = false
                    selectedPlaylistIds.removeAll()
                } label: {
                    Text("Cancel")
                        .font(AppFonts.labelMedium)
                        .foregroundColor(theme.currentTheme.primaryColor)
                }
                .buttonStyle(.plain)

                Button {
                    selectAllPlaylists()
                } label: {
                    let visibleSelectable = viewModel.pinnedPlaylists + viewModel.userPlaylists
                    let allVisibleSelected =
                        !visibleSelectable.isEmpty
                        && visibleSelectable.allSatisfy { selectedPlaylistIds.contains($0.id) }
                    Text(allVisibleSelected ? "Deselect All" : "Select All")
                        .font(AppFonts.labelMedium)
                        .foregroundColor(theme.currentTheme.primaryColor)
                }
                .buttonStyle(.plain)
                .padding(.leading, DesignTokens.Spacing.sm)

                Spacer()

                Text("\(selectedPlaylistIds.count) selected")
                    .font(AppFonts.labelMedium)
                    .foregroundColor(.secondary)

                Button {
                    deleteSelectedPlaylists()
                } label: {
                    Image(systemName: "trash")
                        .font(AppFonts.labelLarge)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .disabled(selectedPlaylistIds.isEmpty)
            } else {
                // Normal mode UI
                Image(systemName: "music.note.list")
                    .font(AppFonts.heading4)
                    .foregroundColor(.secondary)

                Text("Playlists")
                    .font(AppFonts.heading4)

                Spacer()

                // Selection mode toggle button
                SelectionModeButton {
                    isSelectionMode = true
                }

                // Create button
                CreatePlaylistButton { showCreatePlaylist = true }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(height: DesignTokens.ControlHeight.xl)
    }

    private struct SortMenuButton: View {
        @Binding var sortOption: PlaylistSortOption
        @Binding var sortAscending: Bool
        @State private var isHovered = false
        @Bindable var theme = AppTheme.shared

        var body: some View {
            Menu {
                // Sort options
                ForEach(PlaylistSortOption.allCases, id: \.self) { option in
                    Button {
                        if sortOption == option {
                            sortAscending.toggle()
                        } else {
                            sortOption = option
                            sortAscending = true
                        }
                    } label: {
                        HStack {
                            Text(option.label)
                            Spacer()
                            if sortOption == option {
                                Image(
                                    systemName: sortAscending
                                        ? option.ascendingIcon : option.descendingIcon)
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(AppFonts.labelLarge)
                    .foregroundColor(isHovered ? theme.currentTheme.primaryColor : .secondary)
                    .frame(width: DesignTokens.ControlHeight.sm, height: DesignTokens.ControlHeight.sm)
                    .background(
                        Circle()
                            .fill(
                                isHovered
                                    ? theme.currentTheme.primaryColor.opacity(0.12) : Color.clear)
                    )
                    .scaleEffect(isHovered ? 1.08 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            }
            .frame(width: DesignTokens.ControlHeight.sm)
            .menuStyle(.borderlessButton)
            .onHover { hovering in
                isHovered = hovering
            }
            .help("Sort Playlists")
        }
    }

    private struct CreatePlaylistButton: View {
        let action: () -> Void
        @State private var isHovered = false
        @Bindable var theme = AppTheme.shared

        var body: some View {
            Button(action: action) {
                Image(systemName: "plus")
                    .font(AppFonts.heading4)
                    .foregroundColor(isHovered ? .white : theme.currentTheme.primaryColor)
                    .frame(width: DesignTokens.ControlHeight.sm, height: DesignTokens.ControlHeight.sm)
                    .background(
                        Circle()
                            .fill(
                                isHovered
                                    ? theme.currentTheme.primaryColor
                                    : theme.currentTheme.primaryColor.opacity(0.12))
                    )
                    .scaleEffect(isHovered ? 1.08 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovered = hovering
            }
            .help("Create New Playlist")
        }
    }

    private struct SelectionModeButton: View {
        let action: () -> Void
        @State private var isHovered = false
        @Bindable var theme = AppTheme.shared

        var body: some View {
            Button(action: action) {
                Image(systemName: "checkmark.circle")
                    .font(AppFonts.labelLarge)
                    .foregroundColor(isHovered ? theme.currentTheme.primaryColor : .secondary)
                    .frame(width: DesignTokens.ControlHeight.sm, height: DesignTokens.ControlHeight.sm)
                    .background(
                        Circle()
                            .fill(
                                isHovered
                                    ? theme.currentTheme.primaryColor.opacity(0.12) : Color.clear)
                    )
                    .scaleEffect(isHovered ? 1.08 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
            .help("Select Playlists")
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(AppFonts.labelLarge)

            TextField("Search playlists", text: $searchText)
                .textFieldStyle(.plain)
                .font(AppFonts.labelMedium)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(AppFonts.labelLarge)
                }
                .buttonStyle(.plain)
            }

            // Sort button
            SortMenuButton(
                sortOption: $sortOption,
                sortAscending: $sortAscending
            )
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(height: DesignTokens.ControlHeight.xl)
    }

    // MARK: - Section Header

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(AppFonts.labelSmall)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
    }

    // MARK: - Playlist Row

    private func playlistRow(_ playlist: PlaylistItem) -> some View {
        let isSelected = selectedPlaylistIds.contains(playlist.id)
        let canBeDeleted = if case .user = playlist.type { true } else { false }

        return HStack(spacing: DesignTokens.Spacing.md) {
            // Selection checkbox (only for user playlists in selection mode)
            if isSelectionMode && canBeDeleted {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(AppFonts.bodyLarge)
                    .foregroundColor(isSelected ? theme.currentTheme.primaryColor : .secondary)
            }

            // Artwork
            artworkView(for: playlist)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(playlist.name)
                    .font(AppFonts.labelLarge)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    if playlist.isPinned {
                        Image(systemName: "pin.fill")
                            .font(AppFonts.captionSmall)
                            .foregroundColor(theme.currentTheme.primaryColor)
                    }

                    if case .smart(let smartType) = playlist.type {
                        Text(smartType.description)
                            .font(AppFonts.captionMedium)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(
                            "Playlist • \(playlist.trackCount) \(playlist.trackCount == 1 ? "song" : "songs")"
                        )
                        .font(AppFonts.captionMedium)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs)
                .fill(
                    isPlaylistSelected(playlist)
                        ? theme.currentTheme.primaryColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode && canBeDeleted {
                // Toggle selection
                if isSelected {
                    selectedPlaylistIds.remove(playlist.id)
                } else {
                    selectedPlaylistIds.insert(playlist.id)
                }
            } else if !isSelectionMode {
                // Normal navigation
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedEntity = .playlist(playlist)
                }
            }
        }
        .if(!isSelectionMode) { view in
            view.contextMenu {
                playlistContextMenu(playlist)
            }
        }
    }

    // MARK: - Artwork View

    private func artworkView(for playlist: PlaylistItem) -> some View {
        Group {
            if let imageData = playlist.artworkData, let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: DesignTokens.Size.Artwork.md, height: DesignTokens.Size.Artwork.md)
                    .cornerRadius(DesignTokens.CornerRadius.xxs)
            } else {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xxs)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.currentTheme.primaryColor.opacity(0.4),
                                theme.currentTheme.primaryColor.opacity(0.8),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DesignTokens.Size.Artwork.md, height: DesignTokens.Size.Artwork.md)
                    .overlay {
                        Image(systemName: playlist.icon)
                            .font(AppFonts.bodyLarge)
                            .foregroundColor(.white)
                    }
            }
        }
    }

    // MARK: - Helper Methods

    private func isPlaylistSelected(_ playlist: PlaylistItem) -> Bool {
        guard case .playlist(let selectedPlaylist) = selectedEntity else {
            return false
        }
        return selectedPlaylist.id == playlist.id
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func playlistContextMenu(_ playlist: PlaylistItem) -> some View {
        if case .user(let playlistModel) = playlist.type {
            Button {
                Task {
                    await viewModel.togglePin(playlist: playlist)
                }
            } label: {
                Label(
                    playlist.isPinned ? "Unpin" : "Pin to Top",
                    systemImage: playlist.isPinned ? "pin.slash" : "pin")
            }

            Divider()

            Button {
                exportPlaylistToM3U(playlist: playlistModel)
            } label: {
                Label("Export as M3U", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button {
                isSelectionMode = true
                selectedPlaylistIds.insert(playlist.id)
            } label: {
                Label("Select Multiple", systemImage: "checkmark.circle")
            }

            Divider()

            Button(role: .destructive) {
                Task {
                    try await databaseManager.deletePlaylist(playlist)
                }
            } label: {
                Label("Delete Playlist", systemImage: "trash")
            }
        }
    }

    private func deleteSelectedPlaylists() {
        // Extract raw database IDs from the selected strings (e.g., "user_123" -> 123)
        let idsToDelete = selectedPlaylistIds.compactMap { idString -> Int64? in
            if idString.hasPrefix("user_") {
                return Int64(idString.dropFirst(5))
            }
            return nil
        }

        guard !idsToDelete.isEmpty else { return }

        Task {
            do {
                try await databaseManager.deletePlaylists(ids: idsToDelete)

                await MainActor.run {
                    // Exit selection mode and clear selections ONLY on success
                    isSelectionMode = false
                    selectedPlaylistIds.removeAll()
                }
            } catch {
                Logger.error("Failed to delete playlists: \(error)")
            }
        }
    }

    private func selectAllPlaylists() {
        // Collect all currently visible user (deletable) playlists
        let visibleSelectable = viewModel.pinnedPlaylists + viewModel.userPlaylists
        let visibleIds = visibleSelectable.map { $0.id }

        guard !visibleIds.isEmpty else { return }

        // If all visible ones are already selected, deselect them
        let allVisibleSelected = visibleIds.allSatisfy { selectedPlaylistIds.contains($0) }

        if allVisibleSelected {
            for id in visibleIds {
                selectedPlaylistIds.remove(id)
            }
        } else {
            // Otherwise, select all visible ones
            for id in visibleIds {
                selectedPlaylistIds.insert(id)
            }
        }
    }

    private func exportPlaylistToM3U(playlist: Playlist) {
        guard let playlistId = playlist.id else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "m3u")!]
        panel.nameFieldStringValue = "\(playlist.name).m3u"
        panel.message = "Export playlist to M3U file"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do {
                    try await databaseManager.exportPlaylistToM3U(
                        playlistId: playlistId,
                        saveURL: url,
                        useRelativePaths: false
                    )

                    Logger.info("Successfully exported playlist '\(playlist.name)' to \(url.path)")

                    // Show success notification
                    await MainActor.run {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                } catch {
                    Logger.error("Failed to export playlist: \(error)")
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "music.note.list")
                .font(AppFonts.displayLarge)
                .foregroundColor(.secondary.opacity(0.5))

            Text(
                searchText.isEmpty
                    ? "No playlists yet\nCreate your first playlist" : "No playlists found"
            )
            .font(AppFonts.labelMedium)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab: NavigationTab = .home
        @State private var selectedEntity: EntityType?

        var body: some View {
            PlaylistSidebarView(
                selectedTab: $selectedTab,
                selectedEntity: $selectedEntity
            )
            .environment(DatabaseManager.shared)
            .frame(
                width: DesignTokens.Size.Layout.sidebarMinWidth,
                height: DesignTokens.Size.Preview.mainLayoutHeight
            )
        }
    }

    return PreviewWrapper()
}
