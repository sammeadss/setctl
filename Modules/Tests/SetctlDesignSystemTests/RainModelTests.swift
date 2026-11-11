//
//  RainModelTests.swift
//  SetctlModules
//
//  Created by Samuel Meads on 11/10/26.
//

@testable import SetctlDesignSystem
import Testing

@Test func rainGlyphsContainNoEmoji() {
    #expect(!RainGlyphs.all.isEmpty)
    #expect(RainGlyphs.all.allSatisfy { glyph in
        glyph.unicodeScalars.allSatisfy { !$0.properties.isEmojiPresentation }
    })
}

@Test func columnsFallThenWrapBackAboveTheScreen() {
    var generator = SeededGenerator(state: 42)
    var model = RainModel(columns: 1, rows: 20, using: &generator)
    var previousHead = model.columns[0].head
    var fell = false
    var wrapped = false

    for _ in 0 ..< 600 {
        model.advance(by: 0.1, using: &generator)
        let head = model.columns[0].head
        if head > previousHead {
            fell = true
        }
        if head < previousHead {
            wrapped = true
        }
        previousHead = head
    }

    #expect(fell)
    #expect(wrapped)
}

/// SplitMix64, so the "random" rain is the same on every run.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
