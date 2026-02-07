//  PlaylistSidebarView+View.swift
//  HiFidelity
//
//  View helpers for PlaylistSidebarView
//

import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
