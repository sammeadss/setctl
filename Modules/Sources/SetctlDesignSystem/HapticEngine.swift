//
//  HapticEngine.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/7/26.
//

import CoreHaptics

/// Plays Core Haptics patterns. Does nothing on hardware without haptics.
public final class HapticEngine {
    private var engine: CHHapticEngine?

    public init() {
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

    /// Plays the flex-pump haptic: a single strong transient tap.
    public func playFlexPump() {
        guard let engine else { return }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
            ],
            relativeTime: 0
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Haptics are non-critical; never block or crash the boot sequence over a failure here.
        }
    }
}
