//
//  UrgencySettings.swift
//  Hark
//

import Foundation

/// Every weight and cut-off used to work out urgency, kept in one place.
/// All values are starting guesses, to be tuned by testing with recorded clips.
nonisolated struct UrgencySettings: Sendable {
    // Signal weights. They add up to 1.
    var baseDangerWeight = 0.30
    var loudnessWeight = 0.20
    var closingWeight = 0.20
    var suddennessWeight = 0.10
    var persistenceWeight = 0.10
    var confidenceWeight = 0.10

    // Classifier results below this confidence are ignored as noise.
    var minimumConfidence = 0.3

    // Score cut-offs.
    var alertMinimum = 0.25
    var mediumUrgency = 0.4
    var highUrgency = 0.7

    // What counts as a full-strength signal.
    var loudnessForFullSignal = 20.0      // dB above background
    var closingRateForFullSignal = 6.0    // dB per second
    var suddenRiseForFullSignal = 15.0    // dB jump within half a second
    var persistenceForFullSignal = 5.0    // seconds

    // Loudness history.
    var backgroundWindow = 10.0           // seconds
    var trendWindow = 4.0                 // seconds
    var trendRate = 1.5                   // dB per second for "Getting closer"

    // Vibration repeat and how long an alert stays up, from lowest to highest score.
    var slowestRepeat = 8.0               // seconds
    var fastestRepeat = 1.5               // seconds
    var shortestHold = 2.0                // seconds
    var longestHold = 5.0                 // seconds
    var softestVibration = 0.3            // intensity at the alert minimum

    static let standard = UrgencySettings()

    /// Vibration intensity, soft at the alert minimum and full at 1.
    func vibrationIntensity(for score: Double) -> Double {
        blend(from: softestVibration, to: 1, score: score)
    }

    /// Seconds between repeat vibrations while the sound continues.
    func repeatInterval(for score: Double) -> Double {
        blend(from: slowestRepeat, to: fastestRepeat, score: score)
    }

    /// Seconds the alert stays up after the last detection.
    func holdTime(for score: Double) -> Double {
        blend(from: shortestHold, to: longestHold, score: score)
    }

    /// Moves from `low` at the alert minimum to `high` at a score of 1.
    private func blend(from low: Double, to high: Double, score: Double) -> Double {
        let t = min(max((score - alertMinimum) / (1 - alertMinimum), 0), 1)
        return low + (high - low) * t
    }
}
