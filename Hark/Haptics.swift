//
//  Haptics.swift
//  Hark
//

import CoreHaptics
import UIKit

/// Plays a single buzz whose strength follows the urgency score.
final class Haptics {
    private let engine: CHHapticEngine?

    init() {
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            engine = try? CHHapticEngine()
        } else {
            engine = nil
        }
    }

    /// Buzzes at `intensity` from 0 to 1. Stronger buzzes also last longer.
    func buzz(intensity: Double) {
        guard let engine else {
            fallback(intensity: intensity)
            return
        }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
            ],
            relativeTime: 0,
            duration: 0.2 + 0.4 * intensity
        )
        do {
            // Starting again also restarts the engine if iOS stopped it.
            try engine.start()
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback(intensity: intensity)
        }
    }

    /// Standard iOS vibration for phones without Core Haptics.
    private func fallback(intensity: Double) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: CGFloat(intensity))
    }
}
