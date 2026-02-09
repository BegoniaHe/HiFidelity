//
//  AdvancedSettings.swift
//  HiFidelity
//
//  Created by Varun Rathod on 31/10/25.
//

import SwiftUI

struct AdvancedSettings: View {
    @Environment(DatabaseManager.self) var databaseManager
    @AppStorage("artworkCacheSize") private var cacheSize: Double = 500
    @State private var showResetConfirm = false
    @State private var isRebuildingFTS = false
    @State private var isOptimizing = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxl) {
            // Performance
            performanceSection

            Divider()

            // Database
            databaseSection

            Divider()

            // Danger Zone
            dangerZone

            Spacer()
        }
    }

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            Text("Performance")
            .font(AppFonts.heading3)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack {
                    Text("Artwork Cache Size")
                    Spacer()
                    Text("\(Int(cacheSize)) MB")
                        .foregroundColor(.secondary)
                }
                .font(AppFonts.bodySmall)

                Slider(value: $cacheSize, in: 100...1000, step: 100)
                    .onChange(of: cacheSize) { _, newValue in
                        applyCacheSize(Int(newValue))
                    }

                Text("Memory limit for caching album artwork. Larger cache = smoother scrolling.")
                    .font(AppFonts.captionMedium)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var databaseSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Database")
            .font(AppFonts.heading3)

            // Database size and optimize
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Database Size")
                        .font(AppFonts.bodySmall)
                    if let size = databaseManager.getDatabaseSize() {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(AppFonts.captionMedium)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button {
                    isOptimizing = true
                    Task {
                        try? await databaseManager.vacuumDatabase()
                        await MainActor.run {
                            isOptimizing = false
                        }
                    }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xsPlus) {
                        if isOptimizing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: DesignTokens.Size.Icon.xxxs, height: DesignTokens.Size.Icon.xxxs)
                        }
                        Text(isOptimizing ? "Optimizing..." : "Optimize")
                            .font(AppFonts.labelMedium)
                    }
                }
                .disabled(isOptimizing)
            }

            // FTS rebuild
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Search Index")
                        .font(AppFonts.bodySmall)
                    Text("Rebuild full-text search tables for better results")
                        .font(AppFonts.captionMedium)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    isRebuildingFTS = true
                    Task {
                        try? await databaseManager.rebuildFTS()
                        await MainActor.run {
                            isRebuildingFTS = false
                        }
                    }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xsPlus) {
                        if isRebuildingFTS {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: DesignTokens.Size.Icon.xxxs, height: DesignTokens.Size.Icon.xxxs)
                        }
                        Text(isRebuildingFTS ? "Rebuilding..." : "Rebuild FTS")
                            .font(AppFonts.labelMedium)
                    }
                }
                .disabled(isRebuildingFTS)
                .help("Rebuild full-text search indexes to apply enhanced search configuration")
            }
        }
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Danger Zone")
            .font(AppFonts.heading3)
                .foregroundColor(.red)

            Button {
                showResetConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Reset Database")
                }
                .font(AppFonts.labelMedium)
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                        .fill(Color.red)
                )
            }
            .buttonStyle(.plain)
            .alert("Reset Database?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    Task {
                        try? databaseManager.resetDatabase()
                    }
                }
            } message: {
                Text("This will delete all your music library data. This action cannot be undone.")
            }

            Text(
                "This will permanently delete all your library data including folders, tracks, and playlists."
            )
            .font(AppFonts.captionMedium)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Helper Methods

    private func applyCacheSize(_ sizeMB: Int) {
        ArtworkCache.shared.updateCacheSize(sizeMB: sizeMB)
    }
}

#Preview {
    AdvancedSettings()
        .environment(DatabaseManager.shared)
        .frame(
            width: DesignTokens.Size.Preview.advancedSettingsWidth,
            height: DesignTokens.Size.Preview.advancedSettingsHeight
        )
}
