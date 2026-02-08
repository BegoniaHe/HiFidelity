//
//  LibraryTabButton.swift
//  HiFidelity
//
//  Created by Varun Rathod on 31/10/25.
//

import Observation
import SwiftUI

/// Tab button for library navigation - LINE Design System Segmented Control Style
struct LibraryTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @Bindable var theme = AppTheme.shared
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(isSelected ? AppFonts.heading5 : AppFonts.labelLarge)
                    .fixedSize()
                    .frame(width: DesignTokens.Size.Icon.xxs, height: DesignTokens.Size.Icon.xxs)

                Text(title)
                    .font(isSelected ? AppFonts.heading5 : AppFonts.labelLarge)
                    .fixedSize()
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .frame(height: DesignTokens.ControlHeight.md)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .fill(
                        isSelected
                            ? theme.currentTheme.primaryColor.opacity(0.80)
                            : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
                    )
                    .tokenShadow(
                        DesignTokens.Shadow.level1,
                        color: isSelected ? theme.currentTheme.primaryColor.opacity(0.3) : .clear
                    )
            )
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
