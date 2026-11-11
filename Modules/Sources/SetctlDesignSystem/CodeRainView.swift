//
//  CodeRainView.swift
//  SetctlModules
//
//  Created by Samuel Meads on 11/10/26.
//

import SwiftUI

/// Falling multi-script code rain. Purely decorative: it is hidden from VoiceOver and ignores touches, and under
/// Reduce Motion it draws one still frame.
public struct CodeRainView: View {
    private let cellSize: CGFloat
    private let speed: Double
    private let opacity: Double
    private let density: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var simulation = RainSimulation()

    /// `density` is the number of streams per column; higher values fill more of the area.
    public init(cellSize: CGFloat = 16, speed: Double = 1, opacity: Double = 1, density: Int = 1) {
        self.cellSize = cellSize
        self.speed = speed
        self.opacity = opacity
        self.density = density
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { timeline in
            Canvas { context, size in
                let gridColumns = max(Int(size.width / cellSize), 1)
                simulation.update(
                    at: timeline.date,
                    columns: gridColumns * density,
                    rows: max(Int(size.height / cellSize), 1),
                    speed: speed
                )
                draw(simulation.columns, gridColumns: gridColumns, in: &context)
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Each glyph is centered in its own cell, so full-width and narrow scripts share one grid. The head is full
    /// brightness and the trail fades toward its tail.
    private func draw(
        _ columns: [RainColumn],
        gridColumns: Int,
        in context: inout GraphicsContext
    ) {
        for (streamIndex, column) in columns.enumerated() {
            let lane = CGFloat(streamIndex % gridColumns)
            for (glyphIndex, glyph) in column.glyphs.enumerated() {
                let row = Int(column.head.rounded(.down)) - glyphIndex
                guard row >= 0 else { continue }

                let fade = 1 - Double(glyphIndex) / Double(column.length)
                let text = Text(String(glyph))
                    .font(.system(size: cellSize * 0.9, design: .monospaced))
                    .foregroundStyle(Palette.green.opacity(glyphIndex == 0 ? 1 : fade * fade))
                context.draw(
                    text,
                    at: CGPoint(x: (lane + 0.5) * cellSize, y: (CGFloat(row) + 0.5) * cellSize)
                )
            }
        }
    }
}

/// The rain's state between frames. A reference type, so the `Canvas` drawing closure can advance it.
@MainActor
private final class RainSimulation {
    private static let longestFrame = 0.1

    private var model: RainModel?
    private var lastUpdate: Date?
    private var generator = SystemRandomNumberGenerator()

    var columns: [RainColumn] {
        model?.columns ?? []
    }

    /// Rebuilds the rain when the grid size changes, then advances it by the time since the last frame. A long gap
    /// (the app was paused) counts as one short frame instead of a jump.
    func update(at date: Date, columns: Int, rows: Int, speed: Double) {
        if model?.columns.count != columns || model?.rows != rows {
            model = RainModel(columns: columns, rows: rows, using: &generator)
        }
        let elapsed = lastUpdate.map { min(date.timeIntervalSince($0), Self.longestFrame) } ?? 0
        lastUpdate = date
        model?.advance(by: elapsed * speed, using: &generator)
    }
}

#Preview("Behind content") {
    CodeRainView(opacity: 0.6)
        .background(Palette.black)
}

#Preview("Inside the symbol") {
    ZStack {
        PowerSymbol()
            .fill(Palette.green.opacity(0.2))
        CodeRainView(cellSize: 9, speed: 2, density: 5)
            .mask { PowerSymbol() }
            .shadow(color: Palette.green.opacity(0.6), radius: 6)
    }
    .frame(width: 240, height: 240)
    .padding(Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.black)
}
