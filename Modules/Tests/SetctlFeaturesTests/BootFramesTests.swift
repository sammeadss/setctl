//
//  BootFramesTests.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/30/26.
//

@testable import SetctlFeatures
import Testing

@Test func noiseFramesFillTheWholeGrid() {
    let frames = BootFrames(transition: [], resolve: "")
    let lines = frames.noise[0].split(separator: "\n")

    #expect(frames.noise.count == 15)
    #expect(lines.count == BootFrames.rows)
    #expect(lines.allSatisfy { $0.count == BootFrames.columns })
}

@Test func theLastRevealFrameIsTheFirstFigureFrame() {
    let figure = "ab\ncd"
    let frames = BootFrames(transition: [figure], resolve: "xy\nzw")

    #expect(frames.reveal.last == figure)
}

@Test func theLastMorphFrameIsTheResolveFrame() {
    let frames = BootFrames(transition: ["ab\ncd"], resolve: "xy\nzw")

    #expect(frames.morph.last == "xy\nzw")
}

@Test func missingFiguresStillProduceFrames() {
    let frames = BootFrames(transition: [], resolve: "")

    #expect(!frames.reveal.isEmpty)
    #expect(!frames.morph.isEmpty)
}
