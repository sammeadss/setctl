//
//  RainModel.swift
//  SetctlModules
//
//  Created by Samuel Meads on 11/10/26.
//

import Foundation

/// One falling stream: `head` is the row of the leading glyph, and `glyphs[0]` is the head's glyph, with the
/// trail behind it.
struct RainColumn {
    var head: Double
    let speed: Double
    var glyphs: [Character]

    var length: Int {
        glyphs.count
    }
}

/// The state of the rain, with no drawing. A view reads `columns` and calls `advance` once per frame.
struct RainModel {
    private static let lengthRange = 6 ... 18
    private static let speedRange = 6.0 ... 18.0

    private(set) var columns: [RainColumn]
    let rows: Int

    init(columns count: Int, rows: Int, using generator: inout some RandomNumberGenerator) {
        self.rows = rows
        columns = (0 ..< count).map { _ in
            Self.makeColumn(rows: rows, isOnScreen: true, using: &generator)
        }
    }

    /// Moves every column down by `speed * elapsed` rows, so motion does not depend on the frame rate. A column that
    /// has fully left the bottom restarts above the top.
    mutating func advance(by elapsed: TimeInterval, using generator: inout some RandomNumberGenerator) {
        for index in columns.indices {
            let previousRow = Int(columns[index].head.rounded(.down))
            columns[index].head += columns[index].speed * elapsed
            let rowsMoved = Int(columns[index].head.rounded(.down)) - previousRow

            // Each row the head enters shows a new glyph; more than the trail length would only be overwritten.
            for _ in 0 ..< min(max(rowsMoved, 0), columns[index].length) {
                columns[index].glyphs.removeLast()
                columns[index].glyphs.insert(RainGlyphs.random(using: &generator), at: 0)
            }

            if columns[index].head - Double(columns[index].length) > Double(rows) {
                columns[index] = Self.makeColumn(rows: rows, isOnScreen: false, using: &generator)
            }
        }
    }

    private static func makeColumn(
        rows: Int,
        isOnScreen: Bool,
        using generator: inout some RandomNumberGenerator
    ) -> RainColumn {
        let length = Int.random(in: lengthRange, using: &generator)
        let head = isOnScreen
            ? Double.random(in: 0 ..< Double(rows), using: &generator)
            : -Double.random(in: 0 ... Double(rows) / 2, using: &generator)
        return RainColumn(
            head: head,
            speed: Double.random(in: speedRange, using: &generator),
            glyphs: (0 ..< length).map { _ in RainGlyphs.random(using: &generator) }
        )
    }
}
