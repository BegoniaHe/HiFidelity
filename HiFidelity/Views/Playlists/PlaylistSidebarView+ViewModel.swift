//  PlaylistSidebarView+ViewModel.swift
//  HiFidelity
//
//  View model for PlaylistSidebarView
//

import Foundation
import Observation

@MainActor
@Observable
final class PlaylistSidebarViewModel {
    var allPlaylists: [PlaylistItem] = []
    var smartPlaylists: [PlaylistItem] = []
    var pinnedPlaylists: [PlaylistItem] = []
    var userPlaylists: [PlaylistItem] = []
    var isLoading = false

    private let database = DatabaseManager.shared

    func loadPlaylists() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load smart playlists
            smartPlaylists = SmartPlaylistType.allCases.map { type in
                PlaylistItem(
                    id: "smart_\(type.rawValue)",
                    name: type.rawValue,
                    isPinned: false,
                    type: .smart(type)
                )
            }

            // Load user playlists from cache for better performance
            let userPlaylistModels = try await DatabaseCache.shared.getAllPlaylists()
            let userPlaylistItems = userPlaylistModels.map { playlist in
                PlaylistItem(
                    id: "user_\(playlist.id ?? 0)",
                    name: playlist.name,
                    isPinned: playlist.isFavorite,
                    type: .user(playlist)
                )
            }

            // Separate pinned and regular playlists
            pinnedPlaylists = userPlaylistItems.filter { $0.isPinned }
            userPlaylists = userPlaylistItems.filter { !$0.isPinned }

            allPlaylists = smartPlaylists + userPlaylistItems

            Logger.debug("Loaded \(smartPlaylists.count) smart playlists, \(userPlaylistItems.count) user playlists from cache")
        } catch {
            Logger.error("Failed to load playlists: \(error)")
        }
    }

    func filterPlaylists(query: String) {
        guard !query.isEmpty else {
            // Reset filtering by reloading
            Task { await loadPlaylists() }
            return
        }

        let lowercased = query.lowercased()

        smartPlaylists = smartPlaylists.filter { $0.name.lowercased().contains(lowercased) }
        pinnedPlaylists = pinnedPlaylists.filter { $0.name.lowercased().contains(lowercased) }
        userPlaylists = userPlaylists.filter { $0.name.lowercased().contains(lowercased) }
    }

    func sortPlaylists(by option: PlaylistSortOption, ascending: Bool) {
        let sortFunction: (PlaylistItem, PlaylistItem) -> Bool = { item1, item2 in
            let result: Bool

            switch option {
            case .name:
                result = item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            case .dateCreated:
                let date1 = item1.createdDate ?? Date.distantPast
                let date2 = item2.createdDate ?? Date.distantPast
                result = date1 < date2
            case .dateModified:
                let date1 = item1.modifiedDate ?? Date.distantPast
                let date2 = item2.modifiedDate ?? Date.distantPast
                result = date1 < date2
            case .trackCount:
                result = item1.trackCount < item2.trackCount
            }

            return ascending ? result : !result
        }

        pinnedPlaylists.sort(by: sortFunction)
        userPlaylists.sort(by: sortFunction)
    }

    func togglePin(playlist: PlaylistItem) async {
        guard case .user(var playlistModel) = playlist.type else { return }

        do {
            playlistModel.isFavorite.toggle()
            try await database.updatePlaylist(playlistModel)
            await loadPlaylists()
        } catch {
            Logger.error("Failed to toggle pin: \(error)")
        }
    }
}
