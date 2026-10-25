//
//  Urgency.swift
//  Hark
//

import Foundation

/// The six signals behind an urgency score, each from 0 to 1.
nonisolated struct UrgencySignals: Sendable {
    var baseDanger: Double
    var loudness: Double
    var closing: Double
    var suddenness: Double
    var persistence: Double
    var confidence: Double

    /// Weighted sum of the signals, from 0 to 1.
    func score(with settings: UrgencySettings) -> Double {
        let total = baseDanger * settings.baseDangerWeight
            + loudness * settings.loudnessWeight
            + closing * settings.closingWeight
            + suddenness * settings.suddennessWeight
            + persistence * settings.persistenceWeight
            + confidence * settings.confidenceWeight
        return min(max(total, 0), 1)
    }
}

extension UrgencySignals {
    /// Builds the signals for one detection from the raw measurements.
    init(
        kind: SoundKind,
        confidence: Double,
        decibelsAboveBackground: Double,
        trend: Double,
        suddenRise: Double,
        secondsHeard: Double,
        settings: UrgencySettings
    ) {
        self.init(
            baseDanger: kind.baseDanger,
            loudness: Self.fraction(decibelsAboveBackground, of: settings.loudnessForFullSignal),
            closing: Self.fraction(trend, of: settings.closingRateForFullSignal),
            suddenness: Self.fraction(suddenRise, of: settings.suddenRiseForFullSignal),
            persistence: Self.fraction(secondsHeard, of: settings.persistenceForFullSignal),
            confidence: min(max(confidence, 0), 1)
        )
    }

    private static func fraction(_ value: Double, of full: Double) -> Double {
        min(max(value / full, 0), 1)
    }
}
