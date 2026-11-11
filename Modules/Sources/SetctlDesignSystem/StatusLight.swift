//
//  StatusLight.swift
//  SetctlModules
//
//  Created by Samuel Meads on 11/10/26.
//

import SwiftUI

/// A small indicator light like the ones on a PC front panel: faint when off, lit in `color` when on, and
/// flashing while blinking (steady under Reduce Motion).
public struct StatusLight: View {
    public enum Mode {
        case off
        case on
        case blinking
    }

    private let mode: Mode
    private let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBlinkOn = true

    public init(mode: Mode, color: Color) {
        self.mode = mode
        self.color = color
    }

    private var isLit: Bool {
        switch mode {
        case .off: false
        case .on: true
        case .blinking: reduceMotion || isBlinkOn
        }
    }

    public var body: some View {
        Circle()
            .fill(isLit ? color : Palette.greenFaint)
            .frame(width: 10, height: 10)
            .shadow(color: isLit ? color.opacity(0.8) : .clear, radius: 6)
            .animation(.easeOut(duration: 0.15), value: isLit)
            .accessibilityHidden(true)
            .task(id: mode) {
                isBlinkOn = true
                guard mode == .blinking, !reduceMotion else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(400))
                    isBlinkOn.toggle()
                }
            }
    }
}

#Preview {
    HStack(spacing: Spacing.lg) {
        StatusLight(mode: .off, color: Palette.green)
        StatusLight(mode: .on, color: Palette.green)
        StatusLight(mode: .blinking, color: Palette.red)
        StatusLight(mode: .on, color: Palette.amber)
    }
    .padding(Spacing.xxl)
    .background(Palette.black)
}
