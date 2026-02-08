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
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let xsPlus: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let negativeLg: CGFloat = -16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let xxxxl: CGFloat = 40
        static let xxxxxl: CGFloat = 60
    }

    struct CornerRadius {
        static let hairline: CGFloat = 1
        static let xxxs: CGFloat = 2
        static let xxxsPlus: CGFloat = 3
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let smPlus: CGFloat = 7
        static let sm: CGFloat = 8
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
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

    struct Size {
        struct Artwork {
            static let xs: CGFloat = 40
            static let sm: CGFloat = 48
            static let md: CGFloat = 56
            static let mdPlus: CGFloat = 120
            static let lg: CGFloat = 140
            static let xl: CGFloat = 160
            static let xxl: CGFloat = 180
            static let hero: CGFloat = 280
        }

        struct Window {
            static let settingsWidth: CGFloat = 800
            static let settingsHeight: CGFloat = 600
            static let settingsSidebarWidth: CGFloat = 200
            static let settingsContentMinWidth: CGFloat = 500
            static let aboutWidth: CGFloat = 600
            static let aboutHeight: CGFloat = 500
            static let createPlaylistWidth: CGFloat = 600
            static let createPlaylistHeight: CGFloat = 700
            static let equalizerMinWidth: CGFloat = 600
            static let equalizerMinHeight: CGFloat = 500
            static let lyricsSearchWidth: CGFloat = 500
            static let lyricsSearchHeight: CGFloat = 600
            static let miniPlayerWidthArtwork: CGFloat = 440
            static let miniPlayerWidthCompact: CGFloat = 360
            static let miniPlayerHeight: CGFloat = 140
            static let miniPanelHeight: CGFloat = 300
            static let mainMinWidthBothPanels: CGFloat = 1100
            static let mainMinWidthSinglePanel: CGFloat = 900
            static let mainIdealWidth: CGFloat = 1400
            static let mainMinHeight: CGFloat = 680
            static let mainIdealHeight: CGFloat = 900
        }

        struct Layout {
            static let windowWidthCompact: CGFloat = 1200
            static let windowWidthExpanded: CGFloat = 1600
            static let windowWidthRange: CGFloat = 400
            static let sidebarMinWidth: CGFloat = 280
            static let sidebarMidWidth: CGFloat = 350
            static let sidebarCompactRange: CGFloat = 70
            static let sidebarExpandedRange: CGFloat = 30
            static let rightPanelMinWidth: CGFloat = 320
            static let rightPanelMidWidth: CGFloat = 380
            static let rightPanelCompactRange: CGFloat = 60
            static let rightPanelExpandedRange: CGFloat = 40
        }

        struct Preview {
            static let audioSettingsWidth: CGFloat = 700
            static let audioSettingsHeight: CGFloat = 600
            static let appearanceSettingsWidth: CGFloat = 600
            static let appearanceSettingsHeight: CGFloat = 800
            static let aboutWidth: CGFloat = 600
            static let aboutHeight: CGFloat = 500
            static let advancedSettingsWidth: CGFloat = 600
            static let advancedSettingsHeight: CGFloat = 600
            static let librarySettingsWidth: CGFloat = 700
            static let librarySettingsHeight: CGFloat = 600
            static let miniPlayerWidth: CGFloat = 566
            static let miniPlayerHeight: CGFloat = 208
            static let miniPanelWidth: CGFloat = 550
            static let miniPanelHeight: CGFloat = 300
            static let playbackWidth: CGFloat = 900
            static let playbackHeight: CGFloat = 300
            static let progressWidth: CGFloat = 600
            static let progressHeight: CGFloat = 100
            static let playbackControlsWidth: CGFloat = 300
            static let playbackControlsHeight: CGFloat = 100
            static let rightControlsWidth: CGFloat = 340
            static let rightControlsHeight: CGFloat = 60
            static let trackInfoWidth: CGFloat = 320
            static let trackInfoHeight: CGFloat = 80
            static let audioDeviceWidth: CGFloat = 400
            static let audioDeviceHeight: CGFloat = 200
            static let mainLayoutWidth: CGFloat = 1200
            static let mainLayoutHeight: CGFloat = 800
            static let mainContentWidth: CGFloat = 800
            static let mainContentHeight: CGFloat = 600
            static let trackTableWidth: CGFloat = 800
            static let trackTableHeight: CGFloat = 600
            static let homeWidth: CGFloat = 600
            static let homeHeight: CGFloat = 800
            static let headerHeight: CGFloat = 60
            static let rightPanelHeight: CGFloat = 600
        }

        struct Menu {
            static let audioDeviceWidth: CGFloat = 300
            static let audioDeviceMaxHeight: CGFloat = 300
        }

        struct Slider {
            static let volumeWidth: CGFloat = 100
            static let volumePreviewWidth: CGFloat = 150
            static let volumePreviewHeight: CGFloat = 40
        }

        struct Form {
            static let fieldWidth: CGFloat = 150
            static let valueWidth: CGFloat = 60
            static let pickerWidth: CGFloat = 220
            static let valueWideWidth: CGFloat = 70
            static let searchModePickerWidth: CGFloat = 200
            static let textEditorHeight: CGFloat = 80
            static let searchBarMaxWidth: CGFloat = 440
        }

        struct Button {
            static let minWidth: CGFloat = 140
            static let playOverlayLarge: CGFloat = 54
            static let playOverlaySmall: CGFloat = 50
        }

        struct Badge {
            static let minSize: CGFloat = 14
        }

        struct MiniPlayer {
            static let volumePopoverWidth: CGFloat = 50
            static let volumePopoverHeight: CGFloat = 140
            static let eqBarWidth: CGFloat = 2
            static let eqBarMinHeight: CGFloat = 6
            static let eqBarMaxHeight: CGFloat = 14
        }

        struct ProgressBar {
            static let heightCollapsed: CGFloat = 4
            static let heightHover: CGFloat = 8
            static let heightHoverFill: CGFloat = 10
            static let handleOuter: CGFloat = 16
            static let handleInner: CGFloat = 12
            static let handleOffset: CGFloat = 8
            static let previewBubbleWidth: CGFloat = 60
        }

        struct Equalizer {
            static let dialogWidth: CGFloat = 400
            static let dialogInputWidth: CGFloat = 300
            static let presetMenuWidth: CGFloat = 180
            static let preampWidth: CGFloat = 60
            static let bandWidth: CGFloat = 50
            static let separatorWidth: CGFloat = 1
            static let sliderTrackPreamp: CGFloat = 6
            static let sliderTrack: CGFloat = 5
            static let zeroLineWidth: CGFloat = 20
            static let zeroLineHeight: CGFloat = 2
            static let markWidth: CGFloat = 8
            static let markHeight: CGFloat = 1
            static let thumb: CGFloat = 20
            static let sliderHeight: CGFloat = 240
            static let valueHeight: CGFloat = 20
        }

        struct Icon {
            static let xxxs: CGFloat = 12
            static let xxs: CGFloat = 16
            static let xxsPlus: CGFloat = 17
            static let xs: CGFloat = 20
            static let xsPlus: CGFloat = 18
            static let sm: CGFloat = 24
            static let md: CGFloat = 36
            static let app: CGFloat = 80
        }

        struct Card {
            static let themeHeight: CGFloat = 80
        }

        struct Header {
            static let logoWidth: CGFloat = 140
            static let logoHeight: CGFloat = 64
        }

        struct Playback {
            static let trackInfoMinWidth: CGFloat = 200
            static let trackInfoMaxWidth: CGFloat = 280
            static let rightControlsWidth: CGFloat = 420
            static let bottomSpacerHeight: CGFloat = 110
        }

        struct Library {
            static let genreCardHeight: CGFloat = 130
        }

        struct Popover {
            static let notificationWidth: CGFloat = 350
            static let notificationMaxHeight: CGFloat = 400
        }
    }

    struct ShadowLevel {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    struct Border {
        static let hairline: CGFloat = 0.5
        static let selectedStroke: CGFloat = 3
        static let focusedStroke: CGFloat = 1.5
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
