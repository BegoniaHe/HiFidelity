//
//  AppFonts.swift
//  HiFidelity
//
//  Created by Varun Rathod on 19/11/25.
//

import SwiftUI

/// Centralized font system for consistent typography across the app
struct AppFonts {

    // MARK: - Display Fonts (Large Headers)

    static let displayLarge = Font.system(size: 32, weight: .bold)
    static let displayMedium = Font.system(size: 28, weight: .bold)
    static let displaySmall = Font.system(size: 24, weight: .bold)

    // MARK: - Heading Fonts

    static let heading1 = Font.system(size: 22, weight: .bold)
    static let heading2 = Font.system(size: 20, weight: .bold)
    static let heading3 = Font.system(size: 18, weight: .semibold)
    static let heading4 = Font.system(size: 16, weight: .semibold)
    static let heading5 = Font.system(size: 14, weight: .semibold)

    // MARK: - Body Fonts

    static let bodyLarge = Font.system(size: 16, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .regular)
    static let bodySmall = Font.system(size: 14, weight: .regular)

    // MARK: - Label Fonts

    static let labelLarge = Font.system(size: 14, weight: .medium)
    static let labelMedium = Font.system(size: 13, weight: .medium)
    static let labelSmall = Font.system(size: 12, weight: .medium)

    // MARK: - Caption Fonts

    static let captionLarge = Font.system(size: 12, weight: .regular)
    static let captionMedium = Font.system(size: 11, weight: .regular)
    static let captionSmall = Font.system(size: 10, weight: .regular)

    // MARK: - Button Fonts

    static let buttonLarge = Font.system(size: 16, weight: .semibold)
    static let buttonMedium = Font.system(size: 14, weight: .semibold)
    static let buttonSmall = Font.system(size: 12, weight: .semibold)

    // MARK: - Specialized Fonts

    static let trackTitle = heading2
    static let trackArtist = bodyLarge
    static let trackAlbum = bodySmall
    static let trackMetadata = bodySmall

    static func placeholder(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        Font.system(size: size, weight: weight, design: design)
    }
}

/// Extension for easy access to consistent font sizing
extension View {
    func appFont(_ font: Font) -> some View {
        self.font(font)
    }

    func appFont(_ font: Font, lineSpacing: CGFloat, tracking: CGFloat = 0) -> some View {
        self.font(font)
            .lineSpacing(lineSpacing)
            .tracking(tracking)
    }

    func appFont(_ font: Font, tracking: CGFloat) -> some View {
        self.font(font)
            .tracking(tracking)
    }
}
