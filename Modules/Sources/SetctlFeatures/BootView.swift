//
//  BootView.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/7/26.
//

import SetctlDesignSystem
import SwiftUI

/// The launch animation: an ASCII figure that resolves out of noise. Tapping skips it; `onFinished` is called when it
/// ends or is skipped.
public struct BootView: View {
    @State private var bootStart = Date()
    @State private var isSkipped = false
    @State private var bloomIntensity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(StorageKey.hapticsEnabled) private var isHapticsEnabled = true

    private let hapticEngine = HapticEngine()
    let onFinished: () -> Void

    public init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    public var body: some View {
        ZStack {
            Palette.black.ignoresSafeArea()
            content
        }
        .contentShape(Rectangle())
        .onTapGesture { skip() }
        .task { await runSequence() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Setctl starting up")
        .accessibilityAction { skip() }
    }

    private var content: some View {
        TimelineView(.periodic(from: bootStart, by: tickInterval)) { context in
            let elapsed = context.date.timeIntervalSince(bootStart)
            Text(currentFrame(at: elapsed))
                .font(.system(size: figureFontSize, design: .monospaced))
                .foregroundStyle(elapsed < scrambleDuration ? Palette.greenDim : Palette.green)
                .bloom(intensity: bloomIntensity)
        }
    }

    /// Phases in order: noise, reveal of the first figure frame, the transition frames, a hold on the last one, then a
    /// morph into the resolve frame.
    private func currentFrame(at elapsed: TimeInterval) -> String {
        switch elapsed {
        case ..<scrambleDuration:
            return randomNoise()
        case ..<revealEndTime:
            let progress = (elapsed - scrambleDuration) / revealDuration
            return cellReveal(progress: progress, target: transitionFrames.first ?? "")
        case ..<transitionEndTime:
            guard !transitionFrames.isEmpty else { return "" }
            let index = Int((elapsed - revealEndTime) / frameInterval)
            return transitionFrames[min(index, transitionFrames.count - 1)]
        case ..<holdEndTime:
            return transitionFrames.last ?? resolveFrame
        case ..<morphEndTime:
            let progress = (elapsed - holdEndTime) / morphDuration
            return morphedFrame(progress: progress, from: transitionFrames.last ?? resolveFrame, to: resolveFrame)
        default:
            return resolveFrame
        }
    }

    private func runSequence() async {
        // Under Reduce Motion there is no animation to wait for.
        guard !reduceMotion else {
            finish()
            return
        }

        // The bloom and haptic fire when the transition reaches `bloomTriggerFrameIndex`.
        let bloomDelay = scrambleDuration + revealDuration + Double(bloomTriggerFrameIndex) * frameInterval
        try? await Task.sleep(for: .seconds(bloomDelay))
        // A tap while waiting has already finished the boot.
        guard !isSkipped else { return }
        if isHapticsEnabled {
            hapticEngine.playFlexPump()
            withAnimation(.easeOut(duration: 0.15)) { bloomIntensity = 1 }
            withAnimation(.easeIn(duration: 0.65).delay(0.15)) { bloomIntensity = 0 }
        }

        try? await Task.sleep(for: .seconds(totalDuration - bloomDelay))
        guard !isSkipped else { return }
        finish()
    }

    private func skip() {
        isSkipped = true
        finish()
    }

    private func finish() {
        onFinished()
    }

    private let figureFontSize: CGFloat = 6
    private let figureColumns = 90
    private let figureRows = 115
    private let tickInterval: TimeInterval = 0.08
    private let scrambleDuration: TimeInterval = 1.2
    private let transitionHoldDuration: TimeInterval = 1.2
    private let resolveHoldDuration: TimeInterval = 1.05
    private let revealDuration: TimeInterval = 0.3
    private let bloomTriggerFrameIndex = 10
    private let poseHoldDuration: TimeInterval = 0.4
    private let morphDuration: TimeInterval = 0.6
    private let transitionFrames = BootView.loadTransitionFrames()
    private let resolveFrame = BootView.loadResolveFrame()

    private var frameInterval: TimeInterval {
        transitionHoldDuration / Double(max(transitionFrames.count, 1))
    }

    private var revealEndTime: TimeInterval {
        scrambleDuration + revealDuration
    }

    private var transitionEndTime: TimeInterval {
        revealEndTime + transitionHoldDuration
    }

    private var holdEndTime: TimeInterval {
        transitionEndTime + poseHoldDuration
    }

    private var morphEndTime: TimeInterval {
        holdEndTime + morphDuration
    }

    private var totalDuration: TimeInterval {
        morphEndTime + resolveHoldDuration
    }

    /// A missing resource yields no frames rather than a crash; every phase tolerates an empty list.
    private static func loadTransitionFrames() -> [String] {
        guard
            let url = Bundle.module.url(forResource: "frames", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let frames = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return frames
    }

    private static func loadResolveFrame() -> String {
        guard
            let url = Bundle.module.url(forResource: "setctl_resolve", withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text
    }

    private static let noiseGlyphs = Array("01#$%&*@!?+=-:.")

    private func randomNoise() -> String {
        (0 ..< figureRows)
            .map { _ in String((0 ..< figureColumns).map { _ in BootView.noiseGlyphs.randomElement() ?? "." }) }
            .joined(separator: "\n")
    }

    /// One random threshold per character cell, so reveals and morphs uncover cells in a fixed order instead of
    /// re-randomizing every tick.
    private let cellThresholds = BootView.makeCellThresholds(count: 90 * 115) // matches figureColumns × figureRows

    private static func makeCellThresholds(count: Int) -> [Double] {
        (0 ..< count).map { _ in Double.random(in: 0 ... 1) }
    }

    private func cellReveal(progress: Double, target: String) -> String {
        guard !target.isEmpty else { return randomNoise() }
        let targetLines = target.split(separator: "\n", omittingEmptySubsequences: false)
        var cellIndex = 0
        return targetLines.map { line in
            let chars = line.map { char -> Character in
                defer { cellIndex += 1 }
                let threshold = cellIndex < cellThresholds.count ? cellThresholds[cellIndex] : 1
                return progress >= threshold ? char : (BootView.noiseGlyphs.randomElement() ?? ".")
            }
            return String(chars)
        }.joined(separator: "\n")
    }

    private func morphedFrame(progress: Double, from: String, to: String) -> String {
        let fromLines = from.split(separator: "\n", omittingEmptySubsequences: false)
        let toLines = to.split(separator: "\n", omittingEmptySubsequences: false)
        var cellIndex = 0
        return zip(fromLines, toLines).map { fromLine, toLine in
            let chars = zip(fromLine, toLine).map { fromChar, toChar -> Character in
                defer { cellIndex += 1 }
                let threshold = cellIndex < cellThresholds.count ? cellThresholds[cellIndex] : 1
                return progress >= threshold ? toChar : fromChar
            }
            return String(chars)
        }.joined(separator: "\n")
    }
}

#Preview {
    BootView(onFinished: {})
}
