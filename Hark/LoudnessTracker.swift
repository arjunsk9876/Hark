//
//  LoudnessTracker.swift
//  Hark
//

import Foundation

/// Keeps recent microphone loudness so the app can compare a sound with the
/// background noise.
nonisolated struct LoudnessTracker {
    private struct Sample {
        let time: Date
        let level: Double
    }

    private let settings: UrgencySettings
    private var samples: [Sample] = []

    init(settings: UrgencySettings) {
        self.settings = settings
    }

    mutating func add(_ level: Double, at time: Date) {
        samples.append(Sample(time: time, level: level))
        let oldest = time.addingTimeInterval(-settings.backgroundWindow)
        samples.removeAll { $0.time < oldest }
    }

    mutating func reset() {
        samples.removeAll()
    }

    /// Average loudness over the last half second.
    func current(at now: Date) -> Double? {
        average(of: samples.filter { $0.time >= now.addingTimeInterval(-0.5) })
    }

    /// The quiet floor of recent sound: the 20th percentile of the history.
    var background: Double? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.map(\.level).sorted()
        return sorted[sorted.count / 5]
    }

    /// How far the current loudness is above the background, in dB.
    func aboveBackground(at now: Date) -> Double {
        guard let current = current(at: now), let background else { return 0 }
        return max(0, current - background)
    }

    private func average(of samples: [Sample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        return samples.map(\.level).reduce(0, +) / Double(samples.count)
    }
}
