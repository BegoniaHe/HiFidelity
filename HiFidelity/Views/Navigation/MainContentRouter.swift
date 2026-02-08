//
//  MainContentRouter.swift
//  HiFidelity
//
//  Created by Varun Rathod

import SwiftUI
import Observation

/// Centralized content router that handles navigation between different views
struct MainContentRouter: View {
    @Binding var selectedEntity: EntityType?
    @Binding var searchText: String
    @Binding var isSearchActive: Bool

    @Bindable var theme = AppTheme.shared

    var body: some View {
        ZStack {
            // Layer 1 — Home
           HomeView(selectedEntity: $selectedEntity)
               .zIndex(0)

           // Layer 2 — Entity Detail (album/artist/genre)
           if let entity = selectedEntity {
               if isSearchActive {
                   EntityDetailWithNavigation(entity: entity) {
                       selectedEntity = nil
                   }
                   .transition(
                        .opacity
                        .animation(.easeInOut(duration: 0.4))
                   )
                   .zIndex(3)
               } else {
                   EntityDetailWithNavigation(entity: entity) {
                       selectedEntity = nil
                   }
                   .transition(
                        .opacity
                        .animation(.easeInOut(duration: 0.4))
                   )
                   .zIndex(1)
               }

           }

            // Layer 3 — Search
            if isSearchActive && !searchText.isEmpty {
                SearchResultsView(
                    searchQuery: searchText,
                    selectedEntity: $selectedEntity
                )
                .background(.regularMaterial)
                .transition(
                    .opacity
                    .animation(.easeInOut(duration: 0.4))
                )
                .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, DesignTokens.ControlHeight.playbackBar)
        .onChange(of: isSearchActive) { _, _ in
            if selectedEntity != nil && isSearchActive {
                selectedEntity = nil
            }
        }
    }
}

// MARK: - Entity Detail with Navigation

/// Wrapper for EntityDetailView with back navigation
private struct EntityDetailWithNavigation: View {
    let entity: EntityType
    let onBack: () -> Void

        @Bindable var theme = AppTheme.shared

    var body: some View {
        VStack(spacing: 0) {
            // Back button
            backButton

            Divider()

            // Entity detail
            EntityDetailView(entity: entity)
        }
        .background(.ultraThinMaterial)

    }

    private var backButton: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onBack()
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "chevron.left")
                        .font(AppFonts.heading5)
                    Text("Back")
                        .font(AppFonts.labelLarge)
                }
                .foregroundColor(theme.currentTheme.primaryColor)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .frame(height: DesignTokens.ControlHeight.xs)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                        .fill(theme.currentTheme.primaryColor.opacity(0.1))
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.md)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedEntity: EntityType?
        @State private var searchText = ""
        @State private var isSearchActive = false

        var body: some View {
            MainContentRouter(
                selectedEntity: $selectedEntity,
                searchText: $searchText,
                isSearchActive: $isSearchActive
            )
            .environment(DatabaseManager.shared)
            .frame(
                width: DesignTokens.Size.Preview.mainContentWidth,
                height: DesignTokens.Size.Preview.mainContentHeight
            )
        }
    }

    return PreviewWrapper()
}
