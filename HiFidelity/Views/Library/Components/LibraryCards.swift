//
//  LibraryCards.swift
//  HiFidelity
//
//  Created by Varun Rathod on 31/10/25.
//

import Observation
import SwiftUI

// MARK: - Shared Empty State View

func emptyStateView(icon: String, message: String) -> some View {
    VStack(spacing: DesignTokens.Spacing.xl) {
        Image(systemName: icon)
            .font(AppFonts.displayLarge)
            .foregroundColor(.secondary.opacity(0.35))

        Text(message)
            .font(AppFonts.bodyMedium)
            .foregroundColor(.secondary.opacity(0.8))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

// MARK: - Album Card

struct AlbumCard: View {
    let album: Album
    let onTap: () -> Void

    @Bindable var theme = AppTheme.shared
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Artwork
                ZStack {
                    if let albumId = album.id {
                        AlbumArtworkView(
                            albumId: albumId,
                            size: DesignTokens.Size.Artwork.xl,
                            cornerRadius: DesignTokens.CornerRadius.sm
                        )
                        .tokenShadow(
                            isHovered ? DesignTokens.Shadow.level2 : DesignTokens.Shadow.level1)
                    } else {
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                            .fill(theme.currentTheme.primaryColor.opacity(0.3))
                            .frame(
                                width: DesignTokens.Size.Artwork.xl,
                                height: DesignTokens.Size.Artwork.xl
                            )
                            .tokenShadow(DesignTokens.Shadow.level1)
                    }

                    if isHovered {
                        Button(action: playAlbum) {
                            Circle()
                                .fill(theme.currentTheme.primaryColor)
                                .frame(
                                    width: DesignTokens.Size.Button.playOverlayLarge,
                                    height: DesignTokens.Size.Button.playOverlayLarge
                                )
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(AppFonts.heading4)
                                        .foregroundColor(.white)
                                )
                                .tokenShadow(
                                    DesignTokens.Shadow.level2,
                                    color: theme.currentTheme.primaryColor.opacity(0.4)
                                )
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .frame(width: DesignTokens.Size.Artwork.xl, height: DesignTokens.Size.Artwork.xl)
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)

                // Info
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(album.title)
                        .font(AppFonts.heading5)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .help(album.title)

                    Text(album.displayArtist)
                        .font(AppFonts.captionMedium)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    let albumYear =
                        (album.year != nil && !album.year!.isEmpty) ? "\(album.year!) • " : ""
                    Text(
                        "\(albumYear)\(album.trackCount.description) \(album.trackCount == 1 ? "song" : "songs")"
                    )
                    .font(AppFonts.captionSmall)
                    .foregroundColor(.secondary.opacity(0.85))
                    .lineLimit(1)
                }
                .textSelection(.enabled)
            }
            .frame(width: DesignTokens.Size.Artwork.xl, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.sm)
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            AlbumContextMenu(album: album, onViewDetails: onTap)
        }
    }

    private func playAlbum() {
        Task {
            guard let albumId = album.id else { return }
            let databaseManager = DatabaseManager.shared
            do {
                var tracks = try await databaseManager.getTracksForAlbum(albumId: albumId)
                guard !tracks.isEmpty else { return }

                // Apply saved sorting preference
                let sortField =
                    UserDefaults.standard.string(forKey: "albumDetailSortField") ?? "trackNumber"
                let sortAscending = UserDefaults.standard.bool(forKey: "albumDetailSortAscending")

                if let field = TrackSortField.allFields.first(where: { $0.rawValue == sortField }) {
                    let comparators = field.getComparators(ascending: sortAscending)
                    tracks = tracks.sorted(using: comparators)
                }

                await MainActor.run {
                    PlaybackController.shared.playTracks(tracks)
                }
            } catch {
                Logger.error("Failed to play album: \(error)")
            }
        }
    }
}

// MARK: - Artist Card

struct ArtistCard: View {
    let artist: Artist
    let onTap: () -> Void

    @Bindable var theme = AppTheme.shared
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                // Artwork (circular)
                ZStack {
                    if let artistId = artist.id {
                        ArtistArtworkView(artistId: artistId, size: DesignTokens.Size.Artwork.xl)
                            .tokenShadow(
                                isHovered ? DesignTokens.Shadow.level2 : DesignTokens.Shadow.level1)
                    } else {
                        Circle()
                            .fill(theme.currentTheme.primaryColor.opacity(0.3))
                            .frame(
                                width: DesignTokens.Size.Artwork.xl,
                                height: DesignTokens.Size.Artwork.xl
                            )
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(AppFonts.displayLarge)
                                    .foregroundColor(.white.opacity(0.7))
                            )
                            .tokenShadow(DesignTokens.Shadow.level1)
                    }

                    if isHovered {
                        Button(action: playArtist) {
                            Circle()
                                .fill(theme.currentTheme.primaryColor)
                                .frame(
                                    width: DesignTokens.Size.Button.playOverlayLarge,
                                    height: DesignTokens.Size.Button.playOverlayLarge
                                )
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(AppFonts.heading4)
                                        .foregroundColor(.white)
                                )
                                .tokenShadow(
                                    DesignTokens.Shadow.level2,
                                    color: theme.currentTheme.primaryColor.opacity(0.4)
                                )
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .frame(width: DesignTokens.Size.Artwork.xl, height: DesignTokens.Size.Artwork.xl)
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)

                // Info
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text(artist.name)
                        .font(AppFonts.heading5)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(
                        "\(artist.trackCount.description) \(artist.trackCount == 1 ? "song" : "songs")"
                    )
                    .font(AppFonts.captionSmall)
                    .foregroundColor(.secondary.opacity(0.85))
                }
                .textSelection(.enabled)
            }
            .frame(width: DesignTokens.Size.Artwork.xl, alignment: .center)
        }
        .padding(DesignTokens.Spacing.sm)
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            ArtistContextMenu(artist: artist, onViewDetails: onTap)
        }
    }

    private func playArtist() {
        Task {
            guard let artistId = artist.id else { return }
            let databaseManager = DatabaseManager.shared
            do {
                var tracks = try await databaseManager.getTracksForArtist(artistId: artistId)
                guard !tracks.isEmpty else { return }

                // Apply saved sorting preference
                let sortField =
                    UserDefaults.standard.string(forKey: "artistDetailSortField") ?? "title"
                let sortAscending = UserDefaults.standard.bool(forKey: "artistDetailSortAscending")

                if let field = TrackSortField.allFields.first(where: { $0.rawValue == sortField }) {
                    let comparators = field.getComparators(ascending: sortAscending)
                    tracks = tracks.sorted(using: comparators)
                }

                await MainActor.run {
                    PlaybackController.shared.playTracks(tracks)
                }
            } catch {
                Logger.error("Failed to play artist: \(error)")
            }
        }
    }
}

// MARK: - Genre Card

struct GenreCard: View {
    let genre: Genre
    let onTap: () -> Void

    @Bindable var theme = AppTheme.shared
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Background gradient specific to genre
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .fill(genreGradient)
                    .frame(height: DesignTokens.Size.Library.genreCardHeight)

                // Genre info
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(genre.name)
                        .font(AppFonts.heading2)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .tokenShadow(
                            DesignTokens.Shadow.level1,
                            color: .black.opacity(0.2)
                        )

                    Text("\(genre.trackCount) \(genre.trackCount == 1 ? "track" : "tracks")")
                        .font(AppFonts.labelLarge)
                        .foregroundColor(.white.opacity(0.9))
                        .tokenShadow(
                            DesignTokens.Shadow.level1,
                            color: .black.opacity(0.15)
                        )
                }
                .padding(DesignTokens.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .tokenShadow(
                isHovered ? DesignTokens.Shadow.level2 : DesignTokens.Shadow.level1,
                color: .black.opacity(isHovered ? 0.35 : 0.2)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Genre Visual Styling

    private var genreGradient: LinearGradient {
        let colors = genreColorScheme
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var genreColorScheme: [Color] {
        let genreName = genre.name.lowercased()

        // Map genres to color schemes
        switch genreName {
        case let name where name.contains("rock"):
            return [Color(red: 0.8, green: 0.2, blue: 0.2), Color(red: 0.5, green: 0.1, blue: 0.1)]
        case let name where name.contains("jazz"):
            return [
                Color(red: 0.2, green: 0.3, blue: 0.6), Color(red: 0.1, green: 0.15, blue: 0.35)
            ]
        case let name where name.contains("classical"):
            return [
                Color(red: 0.5, green: 0.3, blue: 0.6), Color(red: 0.3, green: 0.15, blue: 0.4)
            ]
        case let name
        where name.contains("electronic") || name.contains("edm") || name.contains("techno"):
            return [Color(red: 0.0, green: 0.7, blue: 0.9), Color(red: 0.0, green: 0.4, blue: 0.6)]
        case let name where name.contains("pop"):
            return [
                Color(red: 0.9, green: 0.3, blue: 0.6), Color(red: 0.6, green: 0.15, blue: 0.4)
            ]
        case let name where name.contains("hip hop") || name.contains("rap"):
            return [
                Color(red: 0.3, green: 0.25, blue: 0.3), Color(red: 0.15, green: 0.12, blue: 0.15)
            ]
        case let name where name.contains("metal"):
            return [
                Color(red: 0.2, green: 0.2, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.05)
            ]
        case let name where name.contains("country"):
            return [Color(red: 0.7, green: 0.5, blue: 0.2), Color(red: 0.5, green: 0.3, blue: 0.1)]
        case let name where name.contains("blues"):
            return [
                Color(red: 0.1, green: 0.3, blue: 0.5), Color(red: 0.05, green: 0.15, blue: 0.3)
            ]
        case let name where name.contains("reggae"):
            return [Color(red: 0.0, green: 0.6, blue: 0.3), Color(red: 0.0, green: 0.4, blue: 0.2)]
        case let name where name.contains("folk"):
            return [Color(red: 0.5, green: 0.6, blue: 0.3), Color(red: 0.3, green: 0.4, blue: 0.2)]
        case let name where name.contains("r&b") || name.contains("soul"):
            return [
                Color(red: 0.6, green: 0.2, blue: 0.4), Color(red: 0.4, green: 0.1, blue: 0.25)
            ]
        case let name where name.contains("indie"):
            return [Color(red: 0.4, green: 0.5, blue: 0.6), Color(red: 0.2, green: 0.3, blue: 0.4)]
        case let name where name.contains("ambient") || name.contains("chill"):
            return [
                Color(red: 0.3, green: 0.5, blue: 0.6), Color(red: 0.15, green: 0.3, blue: 0.4)
            ]
        case let name where name.contains("latin"):
            return [Color(red: 0.9, green: 0.4, blue: 0.2), Color(red: 0.6, green: 0.2, blue: 0.1)]
        default:
            // Generate colors based on hash of genre name for consistency
            let hash = abs(genre.name.hashValue)
            let hue = Double(hash % 360) / 360.0
            return [
                Color(hue: hue, saturation: 0.6, brightness: 0.7),
                Color(hue: hue, saturation: 0.7, brightness: 0.4)
            ]
        }
    }

    private var genreIcon: String {
        let genreName = genre.name.lowercased()

        // Map genres to appropriate SF Symbols
        switch genreName {
        case let name where name.contains("rock"):
            return "bolt.fill"
        case let name where name.contains("jazz"):
            return "music.note"
        case let name where name.contains("classical"):
            return "music.quarternote.3"
        case let name
        where name.contains("electronic") || name.contains("edm") || name.contains("techno"):
            return "waveform"
        case let name where name.contains("pop"):
            return "sparkles"
        case let name where name.contains("hip hop") || name.contains("rap"):
            return "mic.fill"
        case let name where name.contains("metal"):
            return "flame.fill"
        case let name where name.contains("country"):
            return "guitars.fill"
        case let name where name.contains("blues"):
            return "music.note.list"
        case let name where name.contains("reggae"):
            return "waveform.path.ecg"
        case let name where name.contains("folk"):
            return "leaf.fill"
        case let name where name.contains("r&b") || name.contains("soul"):
            return "heart.fill"
        case let name where name.contains("indie"):
            return "paintbrush.fill"
        case let name where name.contains("ambient") || name.contains("chill"):
            return "cloud.fill"
        case let name where name.contains("latin"):
            return "hifispeaker.fill"
        default:
            return "music.note"
        }
    }
}

// MARK: - Track Grid Card

struct TrackGridCard: View {
    let track: Track
    let onPlay: () -> Void

    @Bindable var theme = AppTheme.shared
    @Bindable var playback = PlaybackController.shared
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            // Artwork
            ZStack {
                TrackArtworkView(
                    track: track,
                    size: DesignTokens.Size.Artwork.lg,
                    cornerRadius: DesignTokens.CornerRadius.md
                )
                .tokenShadow(isHovered ? DesignTokens.Shadow.level2 : DesignTokens.Shadow.level1)

                // Play button overlay
                if isHovered {
                    Button(action: onPlay) {
                        Circle()
                            .fill(theme.currentTheme.primaryColor)
                            .frame(
                                width: DesignTokens.Size.Button.playOverlaySmall,
                                height: DesignTokens.Size.Button.playOverlaySmall
                            )
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(AppFonts.heading4)
                                    .foregroundColor(.white)
                            )
                            .tokenShadow(
                                DesignTokens.Shadow.level2,
                                color: theme.currentTheme.primaryColor.opacity(0.4)
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .frame(width: DesignTokens.Size.Artwork.lg, height: DesignTokens.Size.Artwork.lg)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)

            // Track info
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(track.title)
                    .font(AppFonts.labelMedium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(track.artist)
                    .font(AppFonts.captionMedium)
                    .foregroundColor(.secondary.opacity(0.85))
                    .lineLimit(1)
            }
            .textSelection(.enabled)
            .padding(.leading, DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            TrackContextMenu(track: track)
        }
    }
}

// MARK: - Context Menus

struct AlbumContextMenu: View {
    let album: Album
    let onViewDetails: () -> Void

    @Environment(DatabaseManager.self) var databaseManager
    @Bindable var playback = PlaybackController.shared

    var body: some View {
        Group {
            Button {
                playAlbum()
            } label: {
                Label("Play", systemImage: "play.fill")
            }

            Button {
                shuffleAlbum()
            } label: {
                Label("Shuffle", systemImage: "shuffle")
            }

            Button {
                addToQueue()
            } label: {
                Label("Add to Queue", systemImage: "plus")
            }

            Divider()

            Button {
                onViewDetails()
            } label: {
                Label("View Details", systemImage: "info.circle")
            }
        }
    }

    private func addToQueue() {
        Task {
            guard let albumId = album.id else { return }
            do {
                var tracks = try await databaseManager.getTracksForAlbum(albumId: albumId)
                guard !tracks.isEmpty else { return }

                // Apply saved sorting preference
                let sortField =
                    UserDefaults.standard.string(forKey: "albumDetailSortField") ?? "trackNumber"
                let sortAscending = UserDefaults.standard.bool(forKey: "albumDetailSortAscending")

                if let field = TrackSortField.allFields.first(where: { $0.rawValue == sortField }) {
                    let comparators = field.getComparators(ascending: sortAscending)
                    tracks = tracks.sorted(using: comparators)
                }

                await MainActor.run {
                    playback.addToQueue(tracks)
                }
            } catch {
                Logger.error("Failed to add album to queue: \(error)")
            }
        }
    }

    private func playAlbum() {
        Task {
            guard let albumId = album.id else { return }
            do {
                var tracks = try await databaseManager.getTracksForAlbum(albumId: albumId)
                guard !tracks.isEmpty else { return }

                // Apply saved sorting preference
                let sortField =
                    UserDefaults.standard.string(forKey: "albumDetailSortField") ?? "trackNumber"
                let sortAscending = UserDefaults.standard.bool(forKey: "albumDetailSortAscending")

                if let field = TrackSortField.allFields.first(where: { $0.rawValue == sortField }) {
                    let comparators = field.getComparators(ascending: sortAscending)
                    tracks = tracks.sorted(using: comparators)
                }

                await MainActor.run {
                    playback.playTracks(tracks)
                }
            } catch {
                Logger.error("Failed to play album: \(error)")
            }
        }
    }

    private func shuffleAlbum() {
        Task {
            guard let albumId = album.id else { return }
            do {
                var tracks = try await databaseManager.getTracksForAlbum(albumId: albumId)
                guard !tracks.isEmpty else { return }

                // Apply saved sorting preference before shuffling
                let sortField =
                    UserDefaults.standard.string(forKey: "albumDetailSortField") ?? "trackNumber"
                let sortAscending = UserDefaults.standard.bool(forKey: "albumDetailSortAscending")

                if let field = TrackSortField.allFields.first(where: { $0.rawValue == sortField }) {
                    let comparators = field.getComparators(ascending: sortAscending)
                    tracks = tracks.sorted(using: comparators)
                }

                await MainActor.run {
                    playback.playTracksShuffled(tracks)
                }
            } catch {
                Logger.error("Failed to shuffle album: \(error)")
            }
        }
    }
}

struct ArtistContextMenu: View {
    let artist: Artist
    let onViewDetails: () -> Void

    @Environment(DatabaseManager.self) var databaseManager
    @Bindable var playback = PlaybackController.shared

    var body: some View {
        Group {
            Button {
                playArtist()
            } label: {
                Label("Play", systemImage: "play.fill")
            }

            Button {
                shuffleArtist()
            } label: {
                Label("Shuffle", systemImage: "shuffle")
            }

            Button {
                addToQueue()
            } label: {
                Label("Add to Queue", systemImage: "plus")
            }

            Divider()

            Button {
                onViewDetails()
            } label: {
                Label("View Details", systemImage: "info.circle")
            }
        }
    }

    private func addToQueue() {
        Task {
            guard let artistId = artist.id else { return }
            do {
                var tracks = try await databaseManager.getTracksForArtist(artistId: artistId)
                guard !tracks.isEmpty else { return }

                // Apply saved sorting preference
                let sortField =
                    UserDefaults.standard.string(forKey: "artistDetailSortField") ?? "title"
                let sortAscending = UserDefaults.standard.bool(forKey: "artistDetailSortAscending")

                if let field = TrackSortField.allFields.first(where: { $0.rawValue == sortField }) {
                    let comparators = field.getComparators(ascending: sortAscending)
                    tracks = tracks.sorted(using: comparators)
                }

                await MainActor.run {
                    playback.addToQueue(tracks)
                }
            } catch {
                Logger.error("Failed to add artist tracks to queue: \(error)")
            }
        }
    }

    private func playArtist() {
        Task {
            guard let artistId = artist.id else { return }
            do {
                var tracks = try await databaseManager.getTracksForArtist(artistId: artistId)
                guard !tracks.isEmpty else { return }

                // Apply saved sorting preference
                let sortField =
                    UserDefaults.standard.string(forKey: "artistDetailSortField") ?? "title"
                let sortAscending = UserDefaults.standard.bool(forKey: "artistDetailSortAscending")

                if let field = TrackSortField.allFields.first(where: { $0.rawValue == sortField }) {
                    let comparators = field.getComparators(ascending: sortAscending)
                    tracks = tracks.sorted(using: comparators)
                }

                await MainActor.run {
                    playback.playTracks(tracks)
                }
            } catch {
                Logger.error("Failed to play artist: \(error)")
            }
        }
    }

    private func shuffleArtist() {
        Task {
            guard let artistId = artist.id else { return }
            do {
                var tracks = try await databaseManager.getTracksForArtist(artistId: artistId)
                guard !tracks.isEmpty else { return }

                // Apply saved sorting preference before shuffling
                let sortField =
                    UserDefaults.standard.string(forKey: "artistDetailSortField") ?? "title"
                let sortAscending = UserDefaults.standard.bool(forKey: "artistDetailSortAscending")

                if let field = TrackSortField.allFields.first(where: { $0.rawValue == sortField }) {
                    let comparators = field.getComparators(ascending: sortAscending)
                    tracks = tracks.sorted(using: comparators)
                }

                await MainActor.run {
                    playback.playTracksShuffled(tracks)
                }
            } catch {
                Logger.error("Failed to shuffle artist: \(error)")
            }
        }
    }
}
