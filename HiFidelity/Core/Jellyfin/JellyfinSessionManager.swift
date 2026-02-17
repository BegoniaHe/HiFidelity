import Foundation
import Observation

@MainActor
@Observable
final class JellyfinSessionManager {
    static let shared = JellyfinSessionManager()

    var serverURL: String
    var username: String
    var isAuthenticating = false
    var isAuthenticated = false
    var connectedUserName: String?
    var lastErrorMessage: String?

    private(set) var session: JellyfinSession?

    private let defaults = UserDefaults.standard
    private let client = JellyfinClient()

    private let serverURLKey = "jellyfin.serverURL"
    private let usernameKey = "jellyfin.username"
    private let sessionKey = "jellyfin.session"
    private let deviceIdKey = "jellyfin.deviceId"
    private let lastRemoteSyncAtKey = "jellyfin.remoteSyncAt"

    private var cachedAudioTracks: [Track] = []
    private var cachedAudioTracksAt: Date?
    private var cachedAudioTracksServer: String?
    private let tracksCacheTTL: TimeInterval = 120
    private let diskCacheTTL: TimeInterval = 900
    private let defaultPageSize: Int = 200
    private let pagedStateTTL: TimeInterval = 1800
    private(set) var downloadedRemoteItemIds: Set<String> = []

    private var pagedStates: [String: PagedState] = [:]

    private init() {
        self.serverURL = defaults.string(forKey: serverURLKey) ?? ""
        self.username = defaults.string(forKey: usernameKey) ?? ""

        if let sessionData = defaults.data(forKey: sessionKey),
           let restored = try? JSONDecoder().decode(JellyfinSession.self, from: sessionData) {
            self.session = restored
            self.isAuthenticated = true
            self.connectedUserName = restored.userName
        }

        refreshDownloadedItemsIndex()
    }

    func signIn(password: String) async {
        guard !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            lastErrorMessage = "Server URL, username and password are required"
            NotificationManager.shared.addMessage(.warning, "Please fill all Jellyfin login fields")
            return
        }

        isAuthenticating = true
        lastErrorMessage = nil

        do {
            let deviceId = ensureDeviceId()
            let newSession = try await client.authenticate(
                baseURL: serverURL,
                username: username,
                password: password,
                deviceId: deviceId
            )

            session = newSession
            isAuthenticated = true
            connectedUserName = newSession.userName
            clearTrackCache()
            clearAllPagedStates()
            saveState()
            await syncRemoteIndex(forceRefresh: true)

            NotificationManager.shared.addMessage(.info, "Connected to Jellyfin as \(newSession.userName)")
        } catch {
            isAuthenticated = false
            session = nil
            connectedUserName = nil
            lastErrorMessage = error.localizedDescription
            NotificationManager.shared.addMessage(.error, "Jellyfin login failed")
        }

        isAuthenticating = false
    }

    func signOut() {
        session = nil
        isAuthenticated = false
        connectedUserName = nil
        lastErrorMessage = nil
        clearTrackCache()
        clearAllPagedStates()

        defaults.removeObject(forKey: sessionKey)
        saveIdentityOnly()

        NotificationManager.shared.addMessage(.info, "Disconnected from Jellyfin")
    }

    func testConnection() async {
        guard let session else {
            NotificationManager.shared.addMessage(.warning, "Not connected to Jellyfin")
            return
        }

        do {
            let items = try await client.fetchAudioItems(session: session, startIndex: 0, limit: 1)
            NotificationManager.shared.addMessage(.info, "Jellyfin connected (sample query ok, \(items.count) item returned)")
        } catch {
            lastErrorMessage = error.localizedDescription
            NotificationManager.shared.addMessage(.error, "Jellyfin connectivity test failed")
        }
    }

    func fetchAudioTracks(limit: Int = 300, forceRefresh: Bool = false) async throws -> [Track] {
        guard let session else {
            throw JellyfinError.notAuthenticated
        }

        if !forceRefresh, let cached = cachedTracksIfValid(for: session) {
            return Array(cached.prefix(limit))
        }

        if !forceRefresh, let diskCached = loadDiskTrackCache(for: session) {
            setTrackCache(diskCached, for: session)
            return Array(diskCached.prefix(limit))
        }

        let tracks = try await fetchAndMapAudioTracks(limit: max(limit, 1200), session: session)
        setTrackCache(tracks, for: session)

        return Array(tracks.prefix(limit))
    }

    func fetchAudioTracksPage(startIndex: Int, limit: Int = 200) async throws -> JellyfinTrackPage {
        guard let session else {
            throw JellyfinError.notAuthenticated
        }

        let page = try await client.fetchAudioItemsPage(
            session: session,
            startIndex: startIndex,
            limit: limit
        )

        var mappedTracks: [Track] = []
        mappedTracks.reserveCapacity(page.items.count)

        for item in page.items {
            if let track = await mapAudioItemToTrack(item, session: session) {
                mappedTracks.append(track)
            }
        }

        Logger.debug(
            "Jellyfin page mapped: start=\(startIndex), mapped=\(mappedTracks.count), total=\(page.totalRecordCount.map(String.init) ?? "unknown")"
        )

        return JellyfinTrackPage(
            tracks: mappedTracks,
            nextStartIndex: startIndex + page.items.count,
            hasMore: page.hasMore,
            totalRecordCount: page.totalRecordCount
        )
    }

    func savePagedState(tabKey: String, tracks: [Track], nextStartIndex: Int, hasMore: Bool) {
        pagedStates[tabKey] = PagedState(
            tracks: tracks,
            nextStartIndex: nextStartIndex,
            hasMore: hasMore,
            updatedAt: Date()
        )
    }

    func restorePagedState(tabKey: String) -> JellyfinTrackPage? {
        guard let state = pagedStates[tabKey],
              Date().timeIntervalSince(state.updatedAt) <= pagedStateTTL else {
            return nil
        }

        return JellyfinTrackPage(
            tracks: state.tracks,
            nextStartIndex: state.nextStartIndex,
            hasMore: state.hasMore,
            totalRecordCount: nil
        )
    }

    func clearPagedState(tabKey: String) {
        pagedStates.removeValue(forKey: tabKey)
    }

    func resolveArtworkURL(for track: Track) async -> URL? {
        guard let session else { return nil }

        if let remoteArtworkURL = track.remoteArtworkURL {
            return remoteArtworkURL
        }

        if let remoteAlbumId = track.remoteAlbumId {
            return await client.buildPrimaryImageURL(
                itemId: remoteAlbumId,
                imageTag: nil,
                session: session
            )
        }

        if let remoteItemId = track.remoteItemId {
            return await client.buildPrimaryImageURL(
                itemId: remoteItemId,
                imageTag: nil,
                session: session
            )
        }

        return nil
    }

    func isDownloaded(_ track: Track) -> Bool {
        guard let remoteItemId = track.remoteItemId else { return false }
        return downloadedRemoteItemIds.contains(remoteItemId)
    }

    func downloadTrack(_ track: Track) async {
        guard let remoteItemId = track.remoteItemId else { return }

        if downloadedRemoteItemIds.contains(remoteItemId) {
            NotificationManager.shared.addMessage(.info, "Already downloaded")
            return
        }

        do {
            let downloadFolder = try await ensureDownloadFolderTracked()

            let request = URLRequest(url: track.url)
            let (tempURL, response) = try await URLSession.shared.download(for: request)

            let fileExtension = resolveAudioFileExtension(for: response, fallbackURL: track.url)
            let safeTitle = sanitizeFileName("\(track.artist) - \(track.title)")
            let finalURL = downloadFolder.url
                .appendingPathComponent("\(remoteItemId)__\(safeTitle)")
                .appendingPathExtension(fileExtension)

            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            try fileManager.moveItem(at: tempURL, to: finalURL)

            downloadedRemoteItemIds.insert(remoteItemId)
            try await DatabaseManager.shared.rescanFolder(downloadFolder)
            NotificationManager.shared.addMessage(.info, "Downloaded: \(track.title)")
        } catch {
            Logger.error("Failed to download Jellyfin track: \(error)")
            NotificationManager.shared.addMessage(.error, "Failed to download \(track.title)")
        }
    }

    func refreshDownloadedItemsIndex() {
        guard let folderURL = jellyfinDownloadFolderURL() else {
            downloadedRemoteItemIds = []
            return
        }

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            downloadedRemoteItemIds = []
            return
        }

        let ids = files
            .map { $0.deletingPathExtension().lastPathComponent }
            .compactMap { value -> String? in
                guard let separatorRange = value.range(of: "__") else { return nil }
                let remoteId = String(value[..<separatorRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                return remoteId.isEmpty ? nil : remoteId
            }

        downloadedRemoteItemIds = Set(ids)
    }

    func fetchTracksForRemoteAlbum(remoteAlbumId: String?, albumName: String, albumArtist: String?) async throws -> [Track] {
        let source = try await fetchAllCachedOrRemoteTracks()

        if let remoteAlbumId, !remoteAlbumId.isEmpty {
            let matched = source.filter { $0.remoteAlbumId == remoteAlbumId }
            if !matched.isEmpty {
                return matched
            }
        }

        return source.filter {
            let sameAlbum = normalize($0.album) == normalize(albumName)
            guard sameAlbum else { return false }

            if let albumArtist, !normalize(albumArtist).isEmpty {
                return normalize($0.albumArtist ?? $0.artist) == normalize(albumArtist)
            }
            return true
        }
    }

    func fetchTracksForRemoteArtist(name: String) async throws -> [Track] {
        let normalizedArtist = normalize(name)
        let source = try await fetchAllCachedOrRemoteTracks()

        return source.filter { track in
            let names = track.artist
                .split(separator: ",")
                .map { normalize(String($0)) }

            return names.contains(normalizedArtist)
        }
    }

    func fetchTracksForRemoteGenre(name: String) async throws -> [Track] {
        let normalizedGenre = normalize(name)
        let source = try await fetchAllCachedOrRemoteTracks()

        return source.filter { track in
            let names = track.genre
                .split(separator: ",")
                .map { normalize(String($0)) }

            return names.contains(normalizedGenre)
        }
    }

    func searchTracks(query: String, limit: Int = 100) async -> [Track] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard session != nil else { return [] }

        let tokens = trimmed
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return [] }

        do {
            let source = try await fetchAllCachedOrRemoteTracks()

            let filtered = source.filter { track in
                let haystack = [
                    track.title,
                    track.artist,
                    track.album,
                    track.genre,
                ]
                    .joined(separator: " ")
                    .lowercased()

                return tokens.allSatisfy { haystack.contains($0) }
            }

            return Array(filtered.prefix(limit))
        } catch {
            Logger.error("Jellyfin track search failed: \(error)")
            return []
        }
    }

    func resolvePlaybackURL(for track: Track, preferTranscode: Bool = false) async -> URL? {
        guard let session else { return nil }

        guard let remoteItemId = track.remoteItemId, !remoteItemId.isEmpty else {
            return track.url
        }

        if preferTranscode {
            if let transcodeURL = await client.buildAudioTranscodeStreamURL(itemId: remoteItemId, session: session) {
                return transcodeURL
            }

            return await client.buildAudioStreamURL(itemId: remoteItemId, session: session)
        }

        return await client.buildAudioStreamURL(itemId: remoteItemId, session: session)
    }

    func refreshPlaybackURL(for track: Track) async -> URL? {
        await resolvePlaybackURL(for: track, preferTranscode: false)
    }

    func transcodePlaybackURL(for track: Track) async -> URL? {
        await resolvePlaybackURL(for: track, preferTranscode: true)
    }

    func syncRemoteIndex(forceRefresh: Bool = false) async {
        guard let session else { return }

        if !forceRefresh,
           let lastSyncAt = defaults.object(forKey: lastRemoteSyncAtKey) as? Date,
           Date().timeIntervalSince(lastSyncAt) < 600 {
            return
        }

        var startIndex = 0
        var hasMore = true
        var syncedCount = 0

        do {
            while hasMore {
                let page = try await client.fetchAudioItemsPage(
                    session: session,
                    startIndex: startIndex,
                    limit: defaultPageSize
                )

                if page.items.isEmpty {
                    break
                }

                let now = Date()
                var remoteTracks: [RemoteTrack] = []
                remoteTracks.reserveCapacity(page.items.count)

                for item in page.items {
                    guard let streamURL = await client.buildAudioStreamURL(itemId: item.id, session: session) else {
                        continue
                    }

                    let artworkURL: URL?
                    if let albumId = item.albumId {
                        artworkURL = await client.buildPrimaryImageURL(
                            itemId: albumId,
                            imageTag: item.albumPrimaryImageTag,
                            session: session
                        )
                    } else {
                        artworkURL = await client.buildPrimaryImageURL(
                            itemId: item.id,
                            imageTag: item.imageTag,
                            session: session
                        )
                    }

                    remoteTracks.append(
                        RemoteTrack(
                            id: nil,
                            remoteItemId: item.id,
                            remoteAlbumId: item.albumId,
                            title: item.name,
                            artist: item.artists.joined(separator: ", ").isEmpty ? "Unknown Artist" : item.artists.joined(separator: ", "),
                            album: item.album ?? "Unknown Album",
                            albumArtist: item.artists.first,
                            genre: item.genres.first ?? "Unknown Genre",
                            duration: item.durationSeconds ?? 0,
                            streamURL: streamURL.absoluteString,
                            artworkURL: artworkURL?.absoluteString,
                            serverURL: session.baseURL,
                            userId: session.userId,
                            dateAdded: now,
                            dateUpdated: now
                        )
                    )
                }

                try await DatabaseManager.shared.upsertRemoteTracks(remoteTracks)
                syncedCount += remoteTracks.count

                startIndex += page.items.count
                hasMore = page.hasMore && page.items.count == defaultPageSize
            }

            defaults.set(Date(), forKey: lastRemoteSyncAtKey)
            if syncedCount > 0 {
                NotificationCenter.default.post(name: .libraryDataDidChange, object: nil)
            }
            Logger.info("Jellyfin remote index synced: \(syncedCount) tracks")
        } catch {
            Logger.error("Failed to sync Jellyfin remote index: \(error)")
            NotificationManager.shared.addMessage(.error, "Jellyfin sync failed")
        }
    }

    private func fetchAllCachedOrRemoteTracks() async throws -> [Track] {
        guard let session else {
            throw JellyfinError.notAuthenticated
        }

        if let cached = cachedTracksIfValid(for: session) {
            return cached
        }

        if let diskCached = loadDiskTrackCache(for: session) {
            setTrackCache(diskCached, for: session)
            return diskCached
        }

        let tracks = try await fetchAndMapAudioTracks(limit: nil, session: session)
        setTrackCache(tracks, for: session)
        return tracks
    }

    private func fetchAndMapAudioTracks(limit: Int?, session: JellyfinSession) async throws -> [Track] {
        var tracks: [Track] = []
        var startIndex = 0
        var hasMore = true

        while hasMore {
            if let limit, tracks.count >= limit {
                break
            }

            let remaining = limit.map { max(0, $0 - tracks.count) }
            let pageSize = min(defaultPageSize, remaining ?? defaultPageSize)
            if pageSize <= 0 {
                break
            }

            let page = try await client.fetchAudioItemsPage(
                session: session,
                startIndex: startIndex,
                limit: pageSize
            )

            Logger.debug(
                "Jellyfin page fetched: start=\(startIndex), count=\(page.items.count), total=\(page.totalRecordCount.map(String.init) ?? "unknown")"
            )

            if page.items.isEmpty {
                break
            }

            for item in page.items {
                if let track = await mapAudioItemToTrack(item, session: session) {
                    tracks.append(track)
                }
            }

            startIndex += page.items.count
            hasMore = page.hasMore && page.items.count == pageSize
        }

        return limit.map { Array(tracks.prefix($0)) } ?? tracks
    }

    private func mapAudioItemToTrack(_ item: JellyfinAudioItem, session: JellyfinSession) async -> Track? {
        guard let streamURL = await client.buildAudioStreamURL(itemId: item.id, session: session) else {
            return nil
        }

        var track = Track(url: streamURL)
        track.title = item.name
        track.artist = item.artists.joined(separator: ", ").isEmpty ? "Unknown Artist" : item.artists.joined(separator: ", ")
        track.album = item.album ?? "Unknown Album"
        track.duration = item.durationSeconds ?? 0
        track.genre = item.genres.first ?? "Unknown Genre"
        track.composer = "Unknown Composer"
        track.year = ""
        track.dateAdded = Date()
        track.isMetadataLoaded = true
        track.remoteItemId = item.id
        track.remoteAlbumId = item.albumId

        if let albumId = item.albumId {
            track.remoteArtworkURL = await client.buildPrimaryImageURL(
                itemId: albumId,
                imageTag: item.albumPrimaryImageTag,
                session: session
            )
        } else {
            track.remoteArtworkURL = await client.buildPrimaryImageURL(
                itemId: item.id,
                imageTag: item.imageTag,
                session: session
            )
        }

        return track
    }

    private func cachedTracksIfValid(for session: JellyfinSession) -> [Track]? {
        guard !cachedAudioTracks.isEmpty,
              cachedAudioTracksServer == session.baseURL,
              let cachedAt = cachedAudioTracksAt,
              Date().timeIntervalSince(cachedAt) <= tracksCacheTTL else {
            return nil
        }

        return cachedAudioTracks
    }

    private func setTrackCache(_ tracks: [Track], for session: JellyfinSession) {
        cachedAudioTracks = tracks
        cachedAudioTracksAt = Date()
        cachedAudioTracksServer = session.baseURL
        saveDiskTrackCache(tracks, for: session)
    }

    private func clearTrackCache() {
        cachedAudioTracks = []
        cachedAudioTracksAt = nil
        cachedAudioTracksServer = nil
    }

    private func clearAllPagedStates() {
        pagedStates.removeAll()
    }

    private func saveDiskTrackCache(_ tracks: [Track], for session: JellyfinSession) {
        let cachedTracks = tracks.map {
            CachedRemoteTrack(
                url: $0.url.absoluteString,
                title: $0.title,
                artist: $0.artist,
                album: $0.album,
                duration: $0.duration,
                genre: $0.genre,
                composer: $0.composer,
                year: $0.year,
                remoteItemId: $0.remoteItemId,
                remoteAlbumId: $0.remoteAlbumId,
                remoteArtworkURL: $0.remoteArtworkURL?.absoluteString
            )
        }

        guard let data = try? JSONEncoder().encode(cachedTracks) else { return }
        try? data.write(to: diskCacheURL(for: session), options: .atomic)
    }

    private func loadDiskTrackCache(for session: JellyfinSession) -> [Track]? {
        let cacheURL = diskCacheURL(for: session)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
              let modifiedAt = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modifiedAt) <= diskCacheTTL,
              let data = try? Data(contentsOf: cacheURL),
              let cachedTracks = try? JSONDecoder().decode([CachedRemoteTrack].self, from: data) else {
            return nil
        }

        return cachedTracks.compactMap { cached in
            guard let url = URL(string: cached.url) else { return nil }

            var track = Track(url: url)
            track.title = cached.title
            track.artist = cached.artist
            track.album = cached.album
            track.duration = cached.duration
            track.genre = cached.genre
            track.composer = cached.composer
            track.year = cached.year
            track.dateAdded = Date()
            track.isMetadataLoaded = true
            track.remoteItemId = cached.remoteItemId
            track.remoteAlbumId = cached.remoteAlbumId
            track.remoteArtworkURL = cached.remoteArtworkURL.flatMap { URL(string: $0) }
            return track
        }
    }

    private func diskCacheURL(for session: JellyfinSession) -> URL {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        let directory = cacheDirectory.appendingPathComponent("HiFidelity/JellyfinIndex", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let key = "\(session.baseURL)|\(session.userId)"
        let fileName = Data(key.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")

        return directory.appendingPathComponent(fileName + ".json")
    }

    private func ensureDownloadFolderTracked() async throws -> Folder {
        guard let downloadFolderURL = jellyfinDownloadFolderURL() else {
            throw JellyfinError.invalidServerURL
        }

        let folder = try await DatabaseManager.shared.ensureManagedFolderTracked(at: downloadFolderURL)
        refreshDownloadedItemsIndex()
        return folder
    }

    private func jellyfinDownloadFolderURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let bundleID = Bundle.main.bundleIdentifier ?? About.bundleIdentifier
        return appSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("remote", isDirectory: true)
            .appendingPathComponent("jellyfin", isDirectory: true)
    }

    private func sanitizeFileName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = value.components(separatedBy: invalid).joined(separator: "_")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Track" : trimmed
    }

    private func resolveAudioFileExtension(for response: URLResponse, fallbackURL: URL) -> String {
        if let suggested = response.suggestedFilename {
            let ext = URL(fileURLWithPath: suggested).pathExtension.lowercased()
            if !ext.isEmpty {
                return ext
            }
        }

        switch response.mimeType?.lowercased() {
        case "audio/flac": return "flac"
        case "audio/mpeg", "audio/mp3": return "mp3"
        case "audio/mp4", "audio/x-m4a": return "m4a"
        case "audio/aac": return "aac"
        case "audio/ogg": return "ogg"
        case "audio/wav", "audio/x-wav": return "wav"

        default:
            let fallback = fallbackURL.pathExtension.lowercased()
            return fallback.isEmpty ? "m4a" : fallback
        }
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private struct CachedRemoteTrack: Codable {
        let url: String
        let title: String
        let artist: String
        let album: String
        let duration: Double
        let genre: String
        let composer: String
        let year: String
        let remoteItemId: String?
        let remoteAlbumId: String?
        let remoteArtworkURL: String?
    }

    private struct PagedState {
        let tracks: [Track]
        let nextStartIndex: Int
        let hasMore: Bool
        let updatedAt: Date
    }

    private func ensureDeviceId() -> String {
        if let existing = defaults.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }

        let generated = UUID().uuidString
        defaults.set(generated, forKey: deviceIdKey)
        return generated
    }

    private func saveState() {
        saveIdentityOnly()

        guard let session else { return }
        if let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: sessionKey)
        }
    }

    private func saveIdentityOnly() {
        defaults.set(serverURL, forKey: serverURLKey)
        defaults.set(username, forKey: usernameKey)
    }
}
