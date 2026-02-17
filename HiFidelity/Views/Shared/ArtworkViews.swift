//
//  ArtworkViews.swift
//  HiFidelity
//
//  Created by Varun Rathod on 03/11/25.
//

import AppKit
import SwiftUI

// MARK: - Jellyfin Remote Artwork View

struct JellyfinRemoteArtworkView: View {
    let artworkURL: URL
    let size: CGFloat
    let cornerRadius: CGFloat
    let placeholderSymbol: String

    @State private var artwork: NSImage?

    var body: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(nsColor: .controlBackgroundColor))

                    Image(systemName: placeholderSymbol)
                        .font(AppFonts.placeholder(size: size * 0.36))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: artworkURL.absoluteString) {
            artwork = await JellyfinArtworkCache.shared.image(for: artworkURL)
        }
    }
}

// MARK: - Track Artwork View

/// High-performance SwiftUI view for displaying track artwork
/// Features: async loading, caching, task cancellation, equatable optimization
struct TrackArtworkView: View {
    let track: Track
    let size: CGFloat
    let cornerRadius: CGFloat

    @State private var artwork: NSImage?
    @State private var loadTask: Task<Void, Never>?

    init(track: Track, size: CGFloat = 40, cornerRadius: CGFloat = 4) {
        self.track = track
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let artwork = artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: artworkTaskId) {
            await loadArtwork()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(nsColor: .controlBackgroundColor))

            Image(systemName: "music.note")
                .font(AppFonts.placeholder(size: size * 0.4))
                .foregroundColor(.secondary.opacity(0.5))
        }
    }

    private func loadArtwork() async {
        if track.remoteItemId != nil || track.remoteAlbumId != nil || track.remoteArtworkURL != nil {
            let resolvedURL = await JellyfinSessionManager.shared.resolveArtworkURL(for: track)
            if let resolvedURL {
                artwork = await JellyfinArtworkCache.shared.image(for: resolvedURL)
            } else {
                artwork = nil
            }
            return
        }

        guard let trackId = track.trackId else {
            artwork = nil
            return
        }

        // Quick synchronous cache check
        if let cached = ArtworkCache.shared.getCachedArtwork(for: trackId, size: size) {
            artwork = cached
            return
        }

        // Load asynchronously
        loadTask?.cancel()
        loadTask = Task { @MainActor in
            guard !Task.isCancelled else { return }

            await withCheckedContinuation { continuation in
                ArtworkCache.shared.getArtwork(for: trackId, size: size) { image in
                    Task { @MainActor in
                        guard !Task.isCancelled,
                            self.track.trackId == trackId
                        else {
                            continuation.resume()
                            return
                        }
                        self.artwork = image
                        continuation.resume()
                    }
                }
            }
        }

        await loadTask?.value
    }

    private var artworkTaskId: String {
        if let remoteArtworkURL = track.remoteArtworkURL {
            return remoteArtworkURL.absoluteString
        }

        if let trackId = track.trackId {
            return "local_\(trackId)"
        }

        return track.url.absoluteString
    }
}

// MARK: - Album Artwork View

/// High-performance SwiftUI view for displaying album artwork
/// Features: async loading, caching, task cancellation, gradient placeholder
struct AlbumArtworkView: View {
    let albumId: Int64
    let size: CGFloat
    let cornerRadius: CGFloat

    @State private var artwork: NSImage?
    @State private var loadTask: Task<Void, Never>?
    @Environment(AppTheme.self) private var theme

    init(albumId: Int64, size: CGFloat = 160, cornerRadius: CGFloat = 8) {
        self.albumId = albumId
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let artwork = artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: albumId) {
            await loadArtwork()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [theme.currentTheme.primaryColor.opacity(0.6), theme.currentTheme.primaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "music.note")
                .font(AppFonts.placeholder(size: size * 0.4))
                .foregroundColor(.white)
        }
    }

    private func loadArtwork() async {
        // Quick synchronous cache check
        if let cached = ArtworkCache.shared.getCachedAlbumArtwork(for: albumId, size: size) {
            artwork = cached
            return
        }

        // Load asynchronously
        loadTask?.cancel()
        loadTask = Task { @MainActor in
            guard !Task.isCancelled else { return }

            await withCheckedContinuation { continuation in
                ArtworkCache.shared.getAlbumArtwork(for: albumId, size: size) { image in
                    Task { @MainActor in
                        guard !Task.isCancelled else {
                            continuation.resume()
                            return
                        }
                        self.artwork = image
                        continuation.resume()
                    }
                }
            }
        }

        await loadTask?.value
    }
}

// MARK: - Artist Artwork View

/// High-performance SwiftUI view for displaying artist artwork (circular)
/// Features: async loading, caching, task cancellation, circular clipping
struct ArtistArtworkView: View {
    let artistId: Int64
    let size: CGFloat

    @State private var artwork: NSImage?
    @State private var loadTask: Task<Void, Never>?
    @Environment(AppTheme.self) private var theme

    init(artistId: Int64, size: CGFloat = 160) {
        self.artistId = artistId
        self.size = size
    }

    var body: some View {
        Group {
            if let artwork = artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: artistId) {
            await loadArtwork()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private var placeholderView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [theme.currentTheme.primaryColor.opacity(0.6), theme.currentTheme.primaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "person.fill")
                .font(AppFonts.placeholder(size: size * 0.4))
                .foregroundColor(.white)
        }
    }

    private func loadArtwork() async {
        // Quick synchronous cache check
        if let cached = ArtworkCache.shared.getCachedArtistArtwork(for: artistId, size: size) {
            artwork = cached
            return
        }

        // Load asynchronously
        loadTask?.cancel()
        loadTask = Task { @MainActor in
            guard !Task.isCancelled else { return }

            await withCheckedContinuation { continuation in
                ArtworkCache.shared.getArtistArtwork(for: artistId, size: size) { image in
                    Task { @MainActor in
                        guard !Task.isCancelled else {
                            continuation.resume()
                            return
                        }
                        self.artwork = image
                        continuation.resume()
                    }
                }
            }
        }

        await loadTask?.value
    }
}
