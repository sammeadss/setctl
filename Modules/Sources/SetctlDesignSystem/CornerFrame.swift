//
//  CornerFrame.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/6/26.
//

import SwiftUI

/// Wraps content in box-drawing corners. The corners are decorative and hidden from VoiceOver.
public struct CornerFrame<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Spacing.lg)
            .overlay(alignment: .topLeading) { corner("┌") }
            .overlay(alignment: .topTrailing) { corner("┐") }
            .overlay(alignment: .bottomLeading) { corner("└") }
            .overlay(alignment: .bottomTrailing) { corner("┘") }
    }

    private func corner(_ glyph: String) -> some View {
        Text(glyph)
            .font(Typography.body)
            .foregroundStyle(Palette.green)
            .accessibilityHidden(true)
    }
}
