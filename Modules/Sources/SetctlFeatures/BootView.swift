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
        // Build the frames before the first frame is drawn.
        _ = Self.frames
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
    /// morph into the resolve frame. Every frame is prepared in advance; this only picks one.
    private func currentFrame(at elapsed: TimeInterval) -> String {
        let frames = Self.frames
        switch elapsed {
        case ..<scrambleDuration:
            return frames.noise[Int(elapsed / tickInterval) % frames.noise.count]
        case ..<revealEndTime:
            return frames.reveal[frameIndex((elapsed - scrambleDuration) / revealDuration, in: frames.reveal)]
        case ..<transitionEndTime:
            guard !frames.transition.isEmpty else { return "" }
            let index = Int((elapsed - revealEndTime) / frameInterval)
            return frames.transition[min(index, frames.transition.count - 1)]
        case ..<holdEndTime:
            return frames.transition.last ?? frames.resolve
        case ..<morphEndTime:
            return frames.morph[frameIndex((elapsed - holdEndTime) / morphDuration, in: frames.morph)]
        default:
            return frames.resolve
        }
    }

    /// The prepared frame for a 0-to-1 progress through a phase.
    private func frameIndex(_ progress: Double, in frames: [String]) -> Int {
        min(max(Int(progress * Double(frames.count)), 0), frames.count - 1)
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
    private let tickInterval: TimeInterval = 0.08
    private let scrambleDuration: TimeInterval = 1.2
    private let transitionHoldDuration: TimeInterval = 1.2
    private let resolveHoldDuration: TimeInterval = 1.05
    private let revealDuration: TimeInterval = 0.3
    private let bloomTriggerFrameIndex = 10
    private let poseHoldDuration: TimeInterval = 0.4
    private let morphDuration: TimeInterval = 0.6
    private static let frames = BootFrames(transition: loadTransitionFrames(), resolve: loadResolveFrame())

    private var frameInterval: TimeInterval {
        transitionHoldDuration / Double(max(Self.frames.transition.count, 1))
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
}

#Preview {
    BootView(onFinished: {})
}
