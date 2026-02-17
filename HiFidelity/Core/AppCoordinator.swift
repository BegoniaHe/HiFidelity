//
//  AppCoordinator.swift
//  HiFidelity
//
//  Created by Varun Rathod on 26/10/25.
//

import Observation
import SwiftUI

@MainActor
@Observable
class AppCoordinator {
    private(set) static var shared: AppCoordinator?

    // Security-scoped bookmark manager
    let bookmarkManager = SecurityScopedBookmarkManager()

    // Sheet presentation
    var showCreatePlaylist = false
    var trackForNewPlaylist: Track?

    init() {
        Self.shared = self
    }

    // MARK: - Lifecycle Management

    /// Initialize security scopes and load library
    func initializeApp() async {
        Logger.info("Initializing HiFidelity application...")

        await ensureJellyfinDownloadFolderTracked()

        // Initialize security-scoped bookmarks for all folders
        await bookmarkManager.initializeSecurityScopes()

        // Start queue persistence manager
        QueuePersistenceManager.shared.start()

        // Sync Jellyfin remote index for search/metadata if already authenticated
        if JellyfinSessionManager.shared.isAuthenticated {
            await JellyfinSessionManager.shared.syncRemoteIndex(forceRefresh: false)
        }

        // Start folder monitoring if enabled
        await startFolderMonitoring()

        Logger.info("Application initialization complete")
    }

    private func ensureJellyfinDownloadFolderTracked() async {
        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let bundleID = Bundle.main.bundleIdentifier ?? About.bundleIdentifier
            let appDirectory = appSupport.appendingPathComponent(bundleID, isDirectory: true)
            let downloadFolder = appDirectory
                .appendingPathComponent("remote", isDirectory: true)
                .appendingPathComponent("jellyfin", isDirectory: true)

            let folder = try await DatabaseManager.shared.ensureManagedFolderTracked(at: downloadFolder)
            try await DatabaseManager.shared.rescanFolder(folder)
        } catch {
            Logger.error("Failed to track Jellyfin download folder: \(error)")
        }
    }

    /// Start folder monitoring if enabled in preferences
    private func startFolderMonitoring() async {
        let enableFolderWatcher = UserDefaults.standard.bool(forKey: "enableFolderWatcher")

        // Default to true if not set
        let shouldStart = UserDefaults.standard.object(forKey: "enableFolderWatcher") == nil ? true : enableFolderWatcher

        if shouldStart {
            await MainActor.run {
                FolderWatcherService.shared.startWatching(databaseManager: DatabaseManager.shared)
            }
        } else {
            Logger.info("Folder monitoring disabled in preferences")
        }
    }

    /// Cleanup on app termination
    func cleanup() async {
        Logger.info("Cleaning up application resources...")

        // Stop folder monitoring
        await MainActor.run {
            FolderWatcherService.shared.stopWatching()
        }

        // Stop queue persistence and save final state
        await QueuePersistenceManager.shared.stop()

        // Release all security-scoped resources
        await bookmarkManager.stopAccessingAllFolders()

        Logger.info("Application cleanup complete")
    }

    // MARK: - Sheet Presentation

    /// Show create playlist sheet with optional track to add
    func showCreatePlaylist(with track: Track? = nil) {
        trackForNewPlaylist = track
        showCreatePlaylist = true
    }
}
