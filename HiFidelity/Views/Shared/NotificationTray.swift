//
//  NotificationType.swift
//  HiFidelity
//
//  Created by Varun Rathod on 28/10/25.
//

import Observation
import SwiftUI

// MARK: - Notification Types

enum NotificationType {
    case info
    case warning
    case error

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .info: return .accentColor
        case .warning: return .orange
        case .error: return .red
        }
    }
}

extension NotificationType: Codable {}

struct NotificationMessage: Identifiable {
    let id = UUID()
    let type: NotificationType
    let title: String
    let timestamp: Date

    init(type: NotificationType, title: String) {
        self.type = type
        self.title = title
        self.timestamp = Date()
    }
}

// MARK: - Notification Manager

@MainActor
@Observable
class NotificationManager {
    static let shared = NotificationManager()

    var unreadCount = 0
    var messages: [NotificationMessage] = []

    private let messagesKey = "NotificationTrayMessages"
    private let unreadCountKey = "NotificationTrayUnreadCount"

    private init() {
        loadPersistedMessages()
        loadUnreadCount()
    }

    // MARK: - Message Management

    func addMessage(_ type: NotificationType, _ title: String) {
        let message = NotificationMessage(type: type, title: title)
        messages.append(message)
        unreadCount += 1
        saveMessages()
        saveUnreadCount()
    }

    func clearMessages() {
        messages.removeAll()
        unreadCount = 0
        saveMessages()
        saveUnreadCount()
    }

    func removeMessage(_ message: NotificationMessage) {
        messages.removeAll { $0.id == message.id }
        saveMessages()
    }

    func markAllAsRead() {
        unreadCount = 0
        saveUnreadCount()
    }

    // MARK: - Persistence

    private func saveMessages() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let encoded = try? encoder.encode(messages) {
            UserDefaults.standard.set(encoded, forKey: messagesKey)
        }
    }

    private func loadPersistedMessages() {
        guard let data = UserDefaults.standard.data(forKey: messagesKey) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let decoded = try? decoder.decode([NotificationMessage].self, from: data) {
            messages = decoded
        }
    }

    private func saveUnreadCount() {
        UserDefaults.standard.set(unreadCount, forKey: unreadCountKey)
    }

    private func loadUnreadCount() {
        unreadCount = UserDefaults.standard.integer(forKey: unreadCountKey)
    }
}

// Make NotificationMessage conform to Codable for persistence
extension NotificationMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case type, title, timestamp
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(timestamp, forKey: .timestamp)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(NotificationType.self, forKey: .type)
        self.title = try container.decode(String.self, forKey: .title)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
}

// MARK: - Notification Tray View

struct NotificationTray: View {
    @Bindable var manager = NotificationManager.shared
    @State private var showingPopover = false

    var body: some View {
        Button(action: {
            showingPopover.toggle()
            // Mark all as read when user opens the popover
            if showingPopover {
                manager.markAllAsRead()
            }
        }) {
            ZStack(alignment: .topTrailing) {
                // Notification icon
                Image(systemName: notificationIcon)
                    .font(AppFonts.bodyLarge)
                    .foregroundColor(.secondary)
                    .frame(width: DesignTokens.Size.Icon.md, height: DesignTokens.Size.Icon.md)
                    .background(
                        Circle()
                            .fill(Color.clear)
                    )

                // Unread count badge
                if manager.unreadCount > 0 {
                    Text("\(manager.unreadCount)")
                        .font(AppFonts.captionSmall)
                        .foregroundColor(.white)
                        .frame(minWidth: DesignTokens.Size.Badge.minSize, minHeight: DesignTokens.Size.Badge.minSize)
                        .background(
                            Circle()
                                .fill(Color.red)
                        )
                        .offset(x: DesignTokens.Spacing.xs, y: -DesignTokens.Spacing.xs)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(PlainHoverButtonStyle())
        .popover(isPresented: $showingPopover, arrowEdge: .bottom) {
            NotificationPopover(isPresented: $showingPopover)
        }
    }

    // MARK: - Computed Properties

    private var notificationIcon: String {
        if hasNotifications {
            "bell.fill"
        } else {
            "bell"
        }
    }

    private var hasNotifications: Bool {
        !manager.messages.isEmpty
    }

}

// MARK: - Notification Popover

struct NotificationPopover: View {
    @Bindable var manager = NotificationManager.shared
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Notifications")
                    .font(AppFonts.heading4)

                if manager.unreadCount > 0 {
                    Text("(\(manager.unreadCount) new)")
                        .font(AppFonts.captionMedium)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !manager.messages.isEmpty {
                    Button("Clear") {
                        manager.clearMessages()
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Clear all notifications")
                }
            }
            .padding(DesignTokens.Spacing.md)

            Divider()

            // Messages
            if manager.messages.isEmpty {
                emptyState
            } else {
                messagesList
            }
        }
        .frame(width: DesignTokens.Size.Popover.notificationWidth)
        .frame(maxHeight: DesignTokens.Size.Popover.notificationMaxHeight)
        .onAppear {
            // Mark as read when popover appears
            manager.markAllAsRead()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "bell.slash")
                .font(AppFonts.displayLarge)
                .foregroundColor(.secondary)

            Text("No notifications")
                .font(AppFonts.bodySmall)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var messagesList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(manager.messages.reversed()) { message in
                    NotificationRow(message: message) {
                        manager.removeMessage(message)
                    }

                    if message.id != manager.messages.first?.id {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let message: NotificationMessage
    let onDismiss: () -> Void

    @State private var isHovered = false

    private var timeAgoText: String {
        let now = Date()
        let interval = now.timeIntervalSince(message.timestamp)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: message.type.icon)
                .font(AppFonts.labelLarge)
                .foregroundColor(message.type.color)
                .frame(width: DesignTokens.Size.Icon.xs)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(message.title)
                .font(AppFonts.bodySmall)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(timeAgoText)
                    .font(AppFonts.captionMedium)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered {
                Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(AppFonts.captionLarge)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {

        // With notifications
        NotificationTray()
            .onAppear {
                NotificationManager.shared.addMessage(.info, "2 folders refreshed for changes")
                NotificationManager.shared.addMessage(.warning, "1 folder couldn't be accessed")
                NotificationManager.shared.addMessage(.error, "Failed to scan Downloads folder")
            }
    }
    .padding()
}
