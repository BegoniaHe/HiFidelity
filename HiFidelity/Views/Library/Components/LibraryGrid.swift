import SwiftUI

struct LibraryGrid<Content: View>: View {
    let availableWidth: CGFloat
    let preset: DesignTokens.Grid.Preset
    @ViewBuilder let content: () -> Content

    var body: some View {
        LazyVGrid(
            columns: FixedGridLayout.columns(
                availableWidth: availableWidth,
                itemWidth: preset.itemWidth,
                spacing: preset.spacing,
                horizontalPadding: preset.horizontalPadding,
                minColumns: preset.minColumns
            ),
            alignment: .leading,
            spacing: preset.spacing
        ) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LibraryGridScrollView<Content: View>: View {
    let preset: DesignTokens.Grid.Preset
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                LibraryGrid(availableWidth: proxy.size.width, preset: preset) {
                    content()
                }
                .padding(preset.horizontalPadding)
            }
        }
    }
}
