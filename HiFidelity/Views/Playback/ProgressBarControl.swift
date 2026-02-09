//
//  ProgressBarControl.swift
//  HiFidelity
//
//  Created by Varun Rathod

import AppKit
import Observation
import SwiftUI

/// Interactive progress bar with scrubbing support
struct ProgressBarControl: View {
    @Bindable var playback = PlaybackController.shared
    @Bindable var theme = AppTheme.shared

    @State private var hoverLocation: CGPoint?
    @State private var isDragging = false
    @State private var tempProgress: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: isHovering ? DesignTokens.CornerRadius.xxs : DesignTokens.CornerRadius.xxxs)
                    .fill(Color.secondary.opacity(isHovering ? 0.3 : 0.2))
                    .frame(height: isHovering ? DesignTokens.Size.ProgressBar.heightHover : DesignTokens.Size.ProgressBar.heightCollapsed)

                // Progress fill
                RoundedRectangle(cornerRadius: isHovering ? DesignTokens.CornerRadius.xxs : DesignTokens.CornerRadius.xxxs)
                    .fill(progressGradient)
                    .frame(
                        width: geometry.size.width * currentProgress,
                        height: isHovering ? DesignTokens.Size.ProgressBar.heightHoverFill : DesignTokens.Size.ProgressBar.heightCollapsed
                    )

                // Scrubber handle
                if isHovering || isDragging {
                    scrubberHandle
                        .offset(x: geometry.size.width * currentProgress - DesignTokens.Size.ProgressBar.handleOffset)
                        .transition(.scale.combined(with: .opacity))
                }

                if shouldShowPreview {
                    previewBubble(width: geometry.size.width)
                        .offset(x: previewOffsetX(in: geometry.size.width), y: -DesignTokens.Spacing.xxl)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        hoverLocation = value.location
                        tempProgress = max(0, min(1, value.location.x / geometry.size.width))
                    }
                    .onEnded { value in
                        let progress = max(0, min(1, value.location.x / geometry.size.width))
                        playback.setProgress(progress)
                        if value.location.x < 0 || value.location.x > geometry.size.width {
                            hoverLocation = nil
                        } else {
                            hoverLocation = value.location
                        }
                        isDragging = false
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        // Tap is handled by drag gesture with minimumDistance: 0
                    }
            )
            .background(
                HoverTrackingView { location in
                    hoverLocation = location
                }
            )
        }
        .frame(height: isHovering ? DesignTokens.Size.ProgressBar.heightHoverFill : DesignTokens.Size.ProgressBar.heightCollapsed)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
    }

    // MARK: - Subviews

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.currentTheme.primaryColor,
                theme.currentTheme.primaryColor.opacity(0.8),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var scrubberHandle: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: DesignTokens.Size.ProgressBar.handleOuter, height: DesignTokens.Size.ProgressBar.handleOuter)
                .tokenShadow(DesignTokens.Shadow.level1)

            Circle()
                .fill(theme.currentTheme.primaryColor)
                .frame(width: DesignTokens.Size.ProgressBar.handleInner, height: DesignTokens.Size.ProgressBar.handleInner)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
    }

    // MARK: - Computed Properties

    private var currentProgress: Double {
        isDragging ? tempProgress : playback.progress
    }

    private func previewProgress(in width: CGFloat) -> Double {
        if isDragging {
            return tempProgress
        }
        if let hoverLocation {
            let clampedX = max(0, min(width, hoverLocation.x))
            return width > 0 ? clampedX / width : 0
        }
        return playback.progress
    }

    private var isHovering: Bool {
        hoverLocation != nil || isDragging
    }

    private var shouldShowPreview: Bool {
        isDragging || hoverLocation != nil
    }

    private var previewBubbleWidth: CGFloat {
        DesignTokens.Size.ProgressBar.previewBubbleWidth
    }

    private func previewOffsetX(in width: CGFloat) -> CGFloat {
        let rawX = width * previewProgress(in: width) - previewBubbleWidth / 2
        return max(0, min(width - previewBubbleWidth, rawX))
    }

    private func previewBubble(width: CGFloat) -> some View {
        let previewTime = playback.duration * previewProgress(in: width)
        return Text(formatTime(previewTime))
            .font(AppFonts.captionMedium)
            .foregroundColor(.primary)
            .monospacedDigit()
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .frame(width: previewBubbleWidth, alignment: .center)
            .background(
                BlurEffectView(material: .hudWindow, blendingMode: .behindWindow)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }

    private func formatTime(_ time: Double) -> String {
        let totalSeconds = max(0, Int(time))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct BlurEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

private struct HoverTrackingView: NSViewRepresentable {
    var onUpdate: (CGPoint?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = TrackingNSView()
        view.onUpdate = onUpdate
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let trackingView = nsView as? TrackingNSView else { return }
        trackingView.onUpdate = onUpdate
    }

    private final class TrackingNSView: NSView {
        var onUpdate: ((CGPoint?) -> Void)?
        private var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }
            let options: NSTrackingArea.Options = [
                .mouseEnteredAndExited,
                .mouseMoved,
                .activeInActiveApp,
                .inVisibleRect,
            ]
            let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(area)
            trackingArea = area
        }

        override func mouseEntered(with event: NSEvent) {
            updateLocation(with: event)
        }

        override func mouseMoved(with event: NSEvent) {
            updateLocation(with: event)
        }

        override func mouseExited(with event: NSEvent) {
            onUpdate?(nil)
        }

        private func updateLocation(with event: NSEvent) {
            let location = convert(event.locationInWindow, from: nil)
            onUpdate?(location)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        ProgressBarControl()
            .frame(height: DesignTokens.Size.ProgressBar.heightHoverFill)
            .padding()
    }
    .frame(width: DesignTokens.Size.Preview.progressWidth, height: DesignTokens.Size.Preview.progressHeight)
}
