//
//  ResponsiveMainLayout.swift
//  HiFidelity
//
//  Created by Varun Rathod

import SwiftUI

/// Responsive three-panel layout with automatic width calculations
struct ResponsiveMainLayout: View {
    @Binding var showLeftSidebar: Bool
    @Binding var showRightPanel: Bool
    @Binding var selectedTab: NavigationTab
    @Binding var selectedEntity: EntityType?
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    @Binding var rightPanelTab: RightPanelTab

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main three-panel layout
                HStack(spacing: 0) {
                    // Left: Library Sidebar (toggleable)
                    if showLeftSidebar {
                        PlaylistSidebarView(
                            selectedTab: $selectedTab,
                            selectedEntity: $selectedEntity
                        )
                        .frame(width: calculateSidebarWidth(for: geometry.size))
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                        Divider()
                            .transition(.opacity)
                    }

                    // Center: Main Content
                    MainContentRouter(
                        selectedEntity: $selectedEntity,
                        searchText: $searchText,
                        isSearchActive: $isSearchActive
                    )

                    // Right: Tabbed Panel (toggleable)
                    if showRightPanel {
                        Divider()
                            .transition(.opacity)

                        RightPanelView(selectedTab: $rightPanelTab)
                            .frame(width: calculateRightPanelWidth(for: geometry.size))
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showLeftSidebar)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showRightPanel)

                // Bottom: Playback Bar (overlaid)
                VStack {
                    Spacer()
                    BottomPlaybackBar(
                        rightPanelTab: $rightPanelTab,
                        showRightPanel: $showRightPanel,
                        showLeftSidebar: $showLeftSidebar
                    )
                }
            }
            // Add simultaneous gesture to dismiss focus when clicking anywhere
            // This allows underlying views to still receive their own taps
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        NotificationCenter.default.post(name: .dismissAllFocus, object: nil)
                    }
            )
        }
    }

    // MARK: - Responsive Width Calculations

    /// Calculate sidebar width based on window size (280-380px)
    private func calculateSidebarWidth(for size: CGSize) -> CGFloat {
        let windowWidth = size.width

        if windowWidth < DesignTokens.Size.Layout.windowWidthCompact {
            return DesignTokens.Size.Layout.sidebarMinWidth
        } else if windowWidth < DesignTokens.Size.Layout.windowWidthExpanded {
            let ratio = (windowWidth - DesignTokens.Size.Layout.windowWidthCompact)
            / DesignTokens.Size.Layout.windowWidthRange
            return DesignTokens.Size.Layout.sidebarMinWidth
            + (ratio * DesignTokens.Size.Layout.sidebarCompactRange)
        } else {
            let ratio = min(
                (windowWidth - DesignTokens.Size.Layout.windowWidthExpanded)
                / DesignTokens.Size.Layout.windowWidthRange,
                1.0
            )
            return DesignTokens.Size.Layout.sidebarMidWidth
            + (ratio * DesignTokens.Size.Layout.sidebarExpandedRange)
        }
    }

    /// Calculate right panel width based on window size (320-420px)
    private func calculateRightPanelWidth(for size: CGSize) -> CGFloat {
        let windowWidth = size.width

        if windowWidth < DesignTokens.Size.Layout.windowWidthCompact {
            return DesignTokens.Size.Layout.rightPanelMinWidth
        } else if windowWidth < DesignTokens.Size.Layout.windowWidthExpanded {
            let ratio = (windowWidth - DesignTokens.Size.Layout.windowWidthCompact)
            / DesignTokens.Size.Layout.windowWidthRange
            return DesignTokens.Size.Layout.rightPanelMinWidth
            + (ratio * DesignTokens.Size.Layout.rightPanelCompactRange)
        } else {
            let ratio = min(
                (windowWidth - DesignTokens.Size.Layout.windowWidthExpanded)
                / DesignTokens.Size.Layout.windowWidthRange,
                1.0
            )
            return DesignTokens.Size.Layout.rightPanelMidWidth
            + (ratio * DesignTokens.Size.Layout.rightPanelExpandedRange)
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var showLeftSidebar = true
        @State private var showRightPanel = true
        @State private var selectedTab: NavigationTab = .home
        @State private var selectedEntity: EntityType?
        @State private var searchText = ""
        @State private var isSearchActive = false
        @State private var rightPanelTab: RightPanelTab = .queue

        var body: some View {
            ResponsiveMainLayout(
                showLeftSidebar: $showLeftSidebar,
                showRightPanel: $showRightPanel,
                selectedTab: $selectedTab,
                selectedEntity: $selectedEntity,
                searchText: $searchText,
                isSearchActive: $isSearchActive,
                rightPanelTab: $rightPanelTab
            )
            .environment(DatabaseManager.shared)
            .frame(width: DesignTokens.Size.Preview.mainLayoutWidth, height: DesignTokens.Size.Preview.mainLayoutHeight)
        }
    }

    return PreviewWrapper()
}
