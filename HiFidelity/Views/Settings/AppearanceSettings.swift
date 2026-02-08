//
//  AppearanceSettings.swift
//  HiFidelity
//
//  Created by Varun Rathod on 31/10/25.
//

import SwiftUI

/// Advanced appearance settings including theme customization
struct AppearanceSettings: View {
    @Bindable var theme: AppTheme
    @AppStorage("accentOpacity") private var accentOpacity: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxl) {
            // Theme Selection
            themeSection

            Divider()

            // Advanced Options
            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, DesignTokens.Spacing.sm)

        }
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                Text("Theme")
                    .font(AppFonts.heading3)

                Text("Choose your preferred color theme")
                    .font(AppFonts.bodySmall)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100), spacing: DesignTokens.Spacing.lg)
                ], spacing: DesignTokens.Spacing.lg) {
                    ForEach(Theme.allCases) { themeOption in
                        ThemeCard(
                            theme: theme,
                            themeOption: themeOption,
                            opacity: accentOpacity
                        )
                    }
                }
            }

            // Accent opacity
            VStack(spacing: DesignTokens.Spacing.sm) {
                HStack {
                    Text("Accent Color Intensity")
                        .font(AppFonts.heading4)
                    Spacer()
                    Text("\(Int(accentOpacity * 100))%")
                        .font(AppFonts.bodySmall)
                        .foregroundColor(.secondary)
                }

                Slider(value: $accentOpacity, in: 0.5...1.0, step: 0.1)
                    .accentColor(theme.currentTheme.primaryColor)
            }
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            // Reset button
            Button {
                resetToDefaults()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Defaults")
                }
                .font(AppFonts.labelMedium)
                .foregroundColor(theme.currentTheme.primaryColor)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                        .stroke(theme.currentTheme.primaryColor, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func resetToDefaults() {
        accentOpacity = 1.0
        theme.setTheme(.blue)
    }
}

// MARK: - Theme Card

private struct ThemeCard: View {
    @Bindable var theme: AppTheme
    let themeOption: Theme
    let opacity: Double

    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                theme.setTheme(themeOption)
            }
        } label: {
            VStack(spacing: DesignTokens.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                        .fill(
                            LinearGradient(
                                colors: themeOption.gradientColors.map { $0.opacity(opacity) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: DesignTokens.Size.Card.themeHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                                .strokeBorder(
                                    theme.currentTheme == themeOption ? themeOption.primaryColor : Color.clear,
                                    lineWidth: DesignTokens.Border.selectedStroke
                                )
                        )
                        .tokenShadow(
                            DesignTokens.Shadow.level1,
                            color: isHovered ? themeOption.primaryColor.opacity(0.3) : Color.clear
                        )

                    if theme.currentTheme == themeOption {
                Image(systemName: "checkmark.circle.fill")
                    .font(AppFonts.heading2)
                            .foregroundColor(.white)
                            .tokenShadow(DesignTokens.Shadow.level1)
                    }
                }

            Text(themeOption.name)
                .font(AppFonts.bodySmall)
                    .fontWeight(theme.currentTheme == themeOption ? .semibold : .regular)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        AppearanceSettings(theme: AppTheme.shared)
            .padding()
    }
    .frame(
        width: DesignTokens.Size.Preview.appearanceSettingsWidth,
        height: DesignTokens.Size.Preview.appearanceSettingsHeight
    )
}
