import SwiftUI

enum FixedGridLayout {
    static func columns(
        availableWidth: CGFloat,
        itemWidth: CGFloat,
        spacing: CGFloat,
        horizontalPadding: CGFloat,
        minColumns: Int = 1
    ) -> [GridItem] {
        let contentWidth = max(availableWidth - (horizontalPadding * 2), itemWidth)
        let rawCount = Int((contentWidth + spacing) / (itemWidth + spacing))
        let columnCount = max(rawCount, minColumns)
        return Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: columnCount)
    }
}
