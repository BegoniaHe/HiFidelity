//
//  MainWindowController.swift
//  HiFidelity
//
//  Creates or activates the main player window without relying on Scene events.
//

import AppKit
import SwiftUI

@MainActor
enum MainWindowController {
    fileprivate static var mainWindow: NSWindow?
    private static let windowDelegate = MainWindowDelegate()
    fileprivate static let windowPositionXKey = "mainWindowX"
    fileprivate static let windowPositionYKey = "mainWindowY"

    static func show() {
        if let window = existingMainWindow() {
            mainWindow = window
            bringToFront(window)
            return
        }

        let coordinator = AppCoordinator.shared ?? AppCoordinator()
        let rootView = ModernPlayerLayout()
            .environment(DatabaseManager.shared)
            .environment(AppTheme.shared)
            .environment(coordinator)
            .themedAccentColor(AppTheme.shared)

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        configureWindow(window)
        window.isReleasedWhenClosed = false
        window.delegate = windowDelegate
        mainWindow = window
        bringToFront(window)
    }

    private static func existingMainWindow() -> NSWindow? {
        if let window = mainWindow, window.isVisible {
            return window
        }

        let mainWindowId = NSUserInterfaceItemIdentifier("MainPlayerWindow")
        return NSApp.windows.first(where: { $0.identifier == mainWindowId })
    }

    private static func configureWindow(_ window: NSWindow) {
        window.identifier = NSUserInterfaceItemIdentifier("MainPlayerWindow")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)

        let toolbar = NSToolbar(identifier: NSToolbar.Identifier("MainPlayerToolbar"))
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbar?.insertItem(withItemIdentifier: .init("separator"), at: 0)

        applySavedPositionOrCenter(to: window)
    }

    private static func bringToFront(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func applySavedPositionOrCenter(to window: NSWindow) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: windowPositionXKey) != nil,
              defaults.object(forKey: windowPositionYKey) != nil else {
            window.center()
            return
        }

        let positionX = CGFloat(defaults.double(forKey: windowPositionXKey))
        let positionY = CGFloat(defaults.double(forKey: windowPositionYKey))
        window.setFrameOrigin(NSPoint(x: positionX, y: positionY))
    }
}

@MainActor
private final class MainWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        saveWindowPosition(notification)
        MainWindowController.mainWindow = nil
    }

    func windowDidMove(_ notification: Notification) {
        saveWindowPosition(notification)
    }

    private func saveWindowPosition(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let origin = window.frame.origin
        let defaults = UserDefaults.standard
        defaults.set(origin.x, forKey: MainWindowController.windowPositionXKey)
        defaults.set(origin.y, forKey: MainWindowController.windowPositionYKey)
    }
}
