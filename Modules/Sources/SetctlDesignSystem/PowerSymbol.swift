//
//  PowerSymbol.swift
//  SetctlModules
//
//  Created by Samuel Meads on 11/10/26.
//

import SwiftUI

/// The power symbol: a ring open at the top with a vertical bar.
public struct PowerSymbol: Shape {
    /// Stroke thickness as a fraction of the shape's size; the icon uses the default.
    private let weight: Double

    public init(weight: Double = 0.09) {
        self.weight = weight
    }

    public func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let stroke = weight * side

        // Angles run from 3 o'clock with y pointing down, so straight up is -90 degrees and the opening spans
        // 38 degrees to each side of it.
        var ring = Path()
        ring.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: 0.295 * side,
            startAngle: .degrees(-52),
            endAngle: .degrees(232),
            clockwise: false
        )
        var symbol = ring.strokedPath(StrokeStyle(lineWidth: stroke))

        symbol.addRect(CGRect(
            x: rect.midX - stroke / 2,
            y: rect.midY - 0.38 * side,
            width: stroke,
            height: 0.38 * side
        ))
        return symbol
    }
}

#Preview {
    PowerSymbol()
        .fill(Palette.green)
        .frame(width: 200, height: 200)
        .padding(Spacing.lg)
        .background(Palette.black)
}
