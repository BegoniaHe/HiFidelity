//
//  SettingsView.swift
//  HiFidelity
//
//  Created by Varun Rathod on 31/10/25.
//

import Observation
import SwiftUI

/// Main settings view with tabbed interface
struct SettingsView: View {
    @Bindable var theme = AppTheme.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab: SettingsTab = .appearance

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            HStack {
                // Sidebar
                settingsSidebar
                    .frame(minWidth: DesignTokens.Size.Window.settingsSidebarWidth, maxWidth: DesignTokens.Size.Window.settingsSidebarWidth)

                Divider()

                // Content
                settingsContent
                    .frame(minWidth: DesignTokens.Size.Window.settingsContentMinWidth)
            }
        }
        .frame(width: DesignTokens.Size.Window.settingsWidth, height: DesignTokens.Size.Window.settingsHeight)
        .themedAccentColor(theme)
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { notification in
            if let tab = notification.object as? SettingsTab {
                selectedTab = tab
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Settings")
                .font(AppFonts.heading2)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(AppFonts.bodyLarge)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: DesignTokens.ControlHeight.sm)
        .padding(.horizontal, DesignTokens.Spacing.xxl)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    // MARK: - Sidebar

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            ForEach(SettingsTab.allCases) { tab in
                SettingsSidebarButton(
                    theme: theme,
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    selectedTab = tab
                }
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
    }

    // MARK: - Content

    @ViewBuilder
    private var settingsContent: some View {
        Group {
            switch selectedTab {
            case .appearance:
                ScrollView {
                    AppearanceSettings(theme: theme)
                        .padding(DesignTokens.Spacing.xxl)
                }

            case .audio:
                ScrollView {
                    AudioSettingsView()
                        .padding(DesignTokens.Spacing.xxl)
                }

            case .library:
                    LibrarySettings()

            case .jellyfin:
                ScrollView {
                    JellyfinSettings()
                        .padding(DesignTokens.Spacing.xxl)
                }

            case .advanced:
                ScrollView {
                    AdvancedSettings()
                        .padding(DesignTokens.Spacing.xxl)
                }

            case .about:
                ScrollView {
                    AboutMenuView()
                        .padding(DesignTokens.Spacing.xxl)
                }
            }
        }
    }
}

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case appearance
    case audio
    case library
    case jellyfin
    case advanced
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance: return String(localized: "Appearance")
        case .audio: return String(localized: "Audio")
        case .library: return String(localized: "Library")
        case .jellyfin: return String(localized: "Jellyfin")
        case .advanced: return String(localized: "Advanced")
        case .about: return String(localized: "About")
        }
    }

    var icon: String {
        switch self {
        case .appearance: return "paintbrush.fill"
        case .audio: return "speaker.wave.3.fill"
        case .library: return "music.note.list"
        case .jellyfin: return "server.rack"
        case .advanced: return "gearshape.2.fill"
        case .about: return "info.circle.fill"
        }
    }
}

// MARK: - Sidebar Button

private struct SettingsSidebarButton: View {
    @Bindable var theme = AppTheme.shared
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: tab.icon)
                    .font(isSelected ? AppFonts.heading4 : AppFonts.labelLarge)
                    .foregroundColor(iconColor)
                    .frame(width: DesignTokens.ControlHeight.xs)

                Text(tab.title)
                    .font(isSelected ? AppFonts.heading5 : AppFonts.bodySmall)
                    .foregroundColor(textColor)

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(backgroundColor)
            .cornerRadius(DesignTokens.CornerRadius.sm)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var iconColor: Color {
        isSelected ? theme.currentTheme.primaryColor : (isHovered ? .primary : .secondary)
    }

    private var textColor: Color {
        isSelected ? .primary : (isHovered ? .primary.opacity(0.9) : .secondary)
    }

    private var backgroundColor: Color {
        isSelected ? theme.currentTheme.primaryColor.opacity(0.15) : (isHovered ? Color(nsColor: .windowBackgroundColor) : .clear)
    }
}

#Preview {
    SettingsView()
        .environment(DatabaseManager.shared)
}
