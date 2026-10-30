//
//  BootFrames.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/30/26.
//

import Foundation

/// The boot animation's frames, built once so the animation does no string work while it runs.
struct BootFrames {
    static let columns = 90
    static let rows = 115
    private static let glyphs = Array("01#$%&*@!?+=-:.")

    /// Random-character frames for the opening scramble.
    let noise: [String]
    /// Frames that uncover the first figure frame cell by cell; the last equals it.
    let reveal: [String]
    /// Frames that turn the last pose into the resolve frame; the last equals it.
    let morph: [String]
    let transition: [String]
    let resolve: String

    init(transition: [String], resolve: String, noiseCount: Int = 15, revealCount: Int = 4, morphCount: Int = 8) {
        self.transition = transition
        self.resolve = resolve

        // One random threshold per cell, so cells appear in a fixed random order across frames.
        let thresholds = (0 ..< Self.columns * Self.rows).map { _ in Double.random(in: 0 ... 1) }
        let first = transition.first ?? ""
        let last = transition.last ?? resolve

        noise = (0 ..< noiseCount).map { _ in Self.randomNoise() }
        reveal = (1 ... revealCount).map {
            Self.uncover(first, progress: Double($0) / Double(revealCount), thresholds: thresholds)
        }
        morph = (1 ... morphCount).map {
            Self.morph(from: last, to: resolve, progress: Double($0) / Double(morphCount), thresholds: thresholds)
        }
    }

    private static func randomGlyph() -> Character {
        glyphs.randomElement() ?? "."
    }

    private static func randomNoise() -> String {
        (0 ..< rows)
            .map { _ in String((0 ..< columns).map { _ in randomGlyph() }) }
            .joined(separator: "\n")
    }

    private static func threshold(_ thresholds: [Double], at cell: Int) -> Double {
        cell < thresholds.count ? thresholds[cell] : 1
    }

    private static func uncover(_ target: String, progress: Double, thresholds: [Double]) -> String {
        guard !target.isEmpty else { return randomNoise() }
        var cell = 0
        return target.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            String(line.map { character -> Character in
                defer { cell += 1 }
                return progress >= threshold(thresholds, at: cell) ? character : randomGlyph()
            })
        }.joined(separator: "\n")
    }

    private static func morph(from: String, to: String, progress: Double, thresholds: [Double]) -> String {
        let fromLines = from.split(separator: "\n", omittingEmptySubsequences: false)
        let toLines = to.split(separator: "\n", omittingEmptySubsequences: false)
        var cell = 0
        return zip(fromLines, toLines).map { fromLine, toLine in
            String(zip(fromLine, toLine).map { fromCharacter, toCharacter -> Character in
                defer { cell += 1 }
                return progress >= threshold(thresholds, at: cell) ? toCharacter : fromCharacter
            })
        }.joined(separator: "\n")
    }
}
