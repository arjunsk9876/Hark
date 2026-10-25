//
//  Haptics.swift
//  Hark
//

import AudioToolbox
import CoreHaptics
import UIKit

/// Plays a buzz whose strength, sharpness, and pulse count follow the
/// urgency score, so the user can tell how serious a sound is by feel.
final class Haptics {
    private let engine: CHHapticEngine?
    private var engineNeedsStart = true

    init() {
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            engine = try? CHHapticEngine()
        } else {
            engine = nil
        }
        // iOS stops the engine on interruptions and resets it if the haptic
        // server crashes. Either way, start it again before the next buzz.
        engine?.stoppedHandler = { [weak self] _ in
            Task { @MainActor in self?.engineNeedsStart = true }
        }
        engine?.resetHandler = { [weak self] in
            Task { @MainActor in self?.engineNeedsStart = true }
        }
    }

    /// Buzzes `pulses` times at `intensity` and `sharpness`, both from 0 to 1.
    /// Stronger buzzes also last longer.
    func buzz(intensity: Double, sharpness: Double, pulses: Int) {
        // Core Haptics only plays while the app is on screen. With the phone
        // locked or in a pocket, fall back to the system vibration, which
        // still runs while the audio session keeps the app awake.
        guard UIApplication.shared.applicationState == .active else {
            systemVibrate(pulses: pulses)
            return
        }
        guard let engine else {
            fallback(intensity: intensity, pulses: pulses)
            return
        }

        let duration = 0.15 + 0.3 * intensity
        let gap = 0.12
        let events = (0..<max(pulses, 1)).map { index in
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(sharpness)),
                ],
                relativeTime: Double(index) * (duration + gap),
                duration: duration
            )
        }
        do {
            if engineNeedsStart {
                try engine.start()
                engineNeedsStart = false
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            engineNeedsStart = true
            fallback(intensity: intensity, pulses: pulses)
        }
    }

    /// Standard iOS haptic for phones without Core Haptics.
    private func fallback(intensity: Double, pulses: Int) {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        for index in 0..<max(pulses, 1) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.25) {
                generator.impactOccurred(intensity: CGFloat(intensity))
            }
        }
    }

    /// The plain system vibration. It has one fixed strength, so urgency is
    /// carried by the number of pulses.
    private func systemVibrate(pulses: Int) {
        for index in 0..<max(pulses, 1) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.6) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }
}
