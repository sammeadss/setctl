//
//  Scanlines.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/6/26.
//

import SwiftUI

public extension View {
    /// Overlays CRT scanlines. The animation is opt-in in Settings and off under Reduce Motion.
    func scanlines(isEnabled: Bool) -> some View {
        modifier(ScanlinesModifier(isEnabled: isEnabled))
    }
}

private struct ScanlinesModifier: ViewModifier {
    let isEnabled: Bool
    @AppStorage(StorageKey.scanlineMotionEnabled) private var isMotionEnabled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()

    func body(content: Content) -> some View {
        if isEnabled, isMotionEnabled, !reduceMotion {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(startDate)
                content.colorEffect(
                    ShaderLibrary.bundle(.module).scanlines(.float(elapsed)),
                    isEnabled: isEnabled
                )
            }
        } else {
            // Static pattern: no TimelineView, so nothing redraws every frame.
            content.colorEffect(
                ShaderLibrary.bundle(.module).scanlines(.float(0)),
                isEnabled: isEnabled
            )
        }
    }
}

#Preview {
    ZStack {
        Palette.black.ignoresSafeArea()
        Text("SETCTL")
            .font(Typography.hero)
            .foregroundStyle(Palette.green)
    }
    .scanlines(isEnabled: true)
}
