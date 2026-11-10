//
//  HapticEngine.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/7/26.
//

import CoreHaptics

/// Plays Core Haptics patterns. Does nothing on hardware without haptics.
///
/// `@unchecked Sendable` because `CHHapticEngine` is not `Sendable`; `engine` is assigned once during
/// initialization and never replaced.
public final class HapticEngine: @unchecked Sendable {
    public static let shared = HapticEngine()
    private var engine: CHHapticEngine?

    private init() {
        prepareEngine()
    }

    private func prepareEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.resetHandler = { [weak engine] in
                // The system can reset the haptic server (e.g. after an audio interruption); restart it.
                try? engine?.start()
            }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    /// A single strong tap.
    public func playFlexPump() {
        play([tap(intensity: 1.0, sharpness: 0.7, at: 0)])
    }

    /// A firm press followed by a softer release.
    public func playBegin() {
        play([
            tap(intensity: 1.0, sharpness: 0.8, at: 0),
            tap(intensity: 0.5, sharpness: 0.3, at: 0.09),
        ])
    }

    private func tap(intensity: Float, sharpness: Float, at time: TimeInterval) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    private func play(_ events: [CHHapticEvent]) {
        guard let engine else { return }
        do {
            // The system stops the engine while the app is in the background.
            try engine.start()
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Haptics are non-critical; a failure must never block the app.
        }
    }
}
