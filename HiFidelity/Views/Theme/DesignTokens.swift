//
//  DesignTokens.swift
//  HiFidelity
//
//  Centralized sizing and styling tokens
//

import SwiftUI

struct DesignTokens {
    struct Spacing {
        static let hairline: CGFloat = 1
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let xxxxl: CGFloat = 40
        static let xxxxxl: CGFloat = 60
    }

    struct CornerRadius {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }

    struct ControlHeight {
        static let xs: CGFloat = 28
        static let sm: CGFloat = 32
        static let md: CGFloat = 36
        static let lg: CGFloat = 44
        static let xl: CGFloat = 52
        static let xxl: CGFloat = 68
        static let playbackBar: CGFloat = 90
    }

    struct ShadowLevel {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    struct Shadow {
        static let level0 = ShadowLevel(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
        static let level1 = ShadowLevel(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        static let level2 = ShadowLevel(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        static let level3 = ShadowLevel(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func tokenShadow(_ shadow: DesignTokens.ShadowLevel) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    func tokenShadow(_ shadow: DesignTokens.ShadowLevel, color: Color) -> some View {
        self.shadow(color: color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

extension Shape {
    func tokenShadow(_ shadow: DesignTokens.ShadowLevel) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    func tokenShadow(_ shadow: DesignTokens.ShadowLevel, color: Color) -> some View {
        self.shadow(color: color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
