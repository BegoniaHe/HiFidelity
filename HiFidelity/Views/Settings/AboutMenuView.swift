//
//  AboutMenuView.swift
//  HiFidelity
//
//  Created by Varun Rathod on 26/11/25.
//

import Sparkle
import SwiftUI

struct AboutMenuView: View {
    @State private var libraryStats: LibraryStats?
    @AppStorage("automaticUpdatesEnabled")
    private var automaticUpdatesEnabled = true

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            appInfoSection

            if let stats = libraryStats, stats.totalFolders > 0 {
                libraryStatisticsSection
            }

            footerSection
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadLibraryStats()
        }
    }

    private func loadLibraryStats() async {
        do {
            libraryStats = try await DatabaseCache.shared.getLibraryStats()
        } catch {
            Logger.error("Failed to load library stats: \(error)")
        }
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        VStack(spacing: 16) {
            appIcon
            appDetails
        }
    }

    private var appIcon: some View {
        Group {
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Image(systemName: "drop.fill")
                    .font(AppFonts.displayLarge)
                    .foregroundColor(.accentColor)
            }
        }
    }

    private var appDetails: some View {
        VStack(spacing: 8) {
            Text(About.appTitle)
                .font(AppFonts.heading1)

            Text(AppInfo.version)
                .font(AppFonts.bodySmall)
                .foregroundColor(.secondary)

            Toggle("Check for updates automatically", isOn: $automaticUpdatesEnabled)
                .help(String(localized: "Automatically download and install updates when available"))
                .onChange(of: automaticUpdatesEnabled) { _, newValue in
                    if let appDelegate = NSApp.delegate as? AppDelegate,
                        let updater = appDelegate.updaterController?.updater {
                        updater.automaticallyChecksForUpdates = newValue
                    }
                }
        }
    }

    // MARK: - Library Statistics Section

    private var libraryStatisticsSection: some View {
        VStack(spacing: 12) {
            Text("Library Statistics")
                .font(AppFonts.heading4)

            if let stats = libraryStats {
                statisticsRow(stats: stats)
            }
        }
    }

    private func statisticsRow(stats: LibraryStats) -> some View {
        HStack(spacing: 30) {
            statisticItem(
                value: "\(stats.totalFolders)",
                label: "Folders"
            )

            statisticItem(
                value: "\(stats.totalTracks)",
                label: "Tracks"
            )

            statisticItem(
                value: stats.formattedDuration,
                label: "Total Duration"
            )

            statisticItem(
                value: stats.formattedStorage,
                label: "Total Storage"
            )
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }

    private func statisticItem(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFonts.heading2)
            Text(label)
                .font(AppFonts.captionMedium)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack(spacing: 20) {
            FooterLink(
                icon: "globe",
                title: String(localized: "Website"),
                url: URL(string: About.appWebsite)!,
                tooltip: String(localized: "Visit project website")
            )

            FooterLink(
                icon: "questionmark.circle",
                title: String(localized: "Help"),
                url: URL(string: About.appWiki)!,
                tooltip: String(localized: "Visit Help Wiki")
            )

            FooterLink(
                icon: "doc.text",
                title: String(localized: "License"),
                url: URL(string: "\(About.appWebsite)/blob/main/LICENSE"),
                tooltip: String(localized: "View license")
            )

            FooterLink(
                icon: "folder",
                title: String(localized: "App Data"),
                action: {
                    let appDataURL = FileManager.default.urls(
                        for: .applicationSupportDirectory, in: .userDomainMask
                    ).first?
                    .appendingPathComponent(Bundle.main.bundleIdentifier ?? About.bundleIdentifier)

                    if let url = appDataURL {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                    }
                },
                tooltip: String(localized: "Show app data directory in Finder")
            )
        }
    }

    private struct FooterLink: View {
        let icon: String
        let title: String
        var url: URL?
        var action: (() -> Void)?
        let tooltip: String

        @State private var isHovered = false

        var body: some View {
            if let url = url {
                Link(destination: url) {
                    linkContent
                }
                .buttonStyle(.plain)
                .help(tooltip)
            } else if let action = action {
                Button(action: action) {
                    linkContent
                }
                .buttonStyle(.plain)
                .help(tooltip)
            }
        }

        private var linkContent: some View {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(AppFonts.captionLarge)
                Text(title)
                    .font(AppFonts.captionLarge)
            }
            .foregroundColor(isHovered ? .accentColor : .secondary)
            .underline(isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }

}

#Preview {
    ScrollView {
        AboutMenuView()
            .padding(DesignTokens.Spacing.xxl)
    }
    .frame(width: 600, height: 500)
}
