//  CreatePlaylistView+Supporting.swift
//  HiFidelity
//
//  Supporting types for CreatePlaylistView
//

import SwiftUI
import AppKit

// MARK: - Color Scheme Button

struct ColorSchemeButton: View {
    let scheme: PlaylistColorScheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(scheme.gradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        if isSelected {
                            Circle()
                                .stroke(Color.primary, lineWidth: 3)
                        }
                    }

                Text(scheme.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Playlist Color Scheme

enum PlaylistColorScheme: String, CaseIterable {
    case auto = "auto"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case red = "red"
    case orange = "orange"
    case green = "green"
    case teal = "teal"

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .red: return "Red"
        case .orange: return "Orange"
        case .green: return "Green"
        case .teal: return "Teal"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .auto:
            return LinearGradient(
                colors: [Color.gray.opacity(0.6), Color.gray],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .blue:
            return LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .purple:
            return LinearGradient(
                colors: [Color.purple.opacity(0.6), Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pink:
            return LinearGradient(
                colors: [Color.pink.opacity(0.6), Color.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .red:
            return LinearGradient(
                colors: [Color.red.opacity(0.6), Color.red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .orange:
            return LinearGradient(
                colors: [Color.orange.opacity(0.6), Color.orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .green:
            return LinearGradient(
                colors: [Color.green.opacity(0.6), Color.green],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .teal:
            return LinearGradient(
                colors: [Color.teal.opacity(0.6), Color.teal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Image Compressor

struct ImageCompressor {
    /// Compress image to standard size and quality
    /// - Parameters:
    ///   - image: Original NSImage
    ///   - maxSize: Maximum dimension (width or height) in pixels
    /// - Returns: Compressed JPEG data
    static func compress(image: NSImage, maxSize: CGFloat = 512) -> Data? {
        // Calculate new size maintaining aspect ratio
        let originalSize = image.size
        let aspectRatio = originalSize.width / originalSize.height

        var newSize: CGSize
        if originalSize.width > originalSize.height {
            newSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            newSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }

        // Create resized image
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )

        resizedImage.unlockFocus()

        // Convert to JPEG with 80% quality
        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.8]
              ) else {
            return nil
        }

        Logger.info("Image compressed: Original size ~\(originalSize.width)x\(originalSize.height), New size \(newSize.width)x\(newSize.height), Data size: \(jpegData.count / 1024)KB")

        return jpegData
    }
}
