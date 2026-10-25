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

    /// Slope of a line fitted to loudness over the trend window, in dB per
    /// second. Positive means getting louder.
    func trend(at now: Date) -> Double {
        let start = now.addingTimeInterval(-settings.trendWindow)
        let window = samples.filter { $0.time >= start }
        guard window.count >= 4,
              let first = window.first, let last = window.last,
              last.time.timeIntervalSince(first.time) >= settings.trendWindow / 2
        else { return 0 }

        let xs = window.map { $0.time.timeIntervalSince(start) }
        let ys = window.map(\.level)
        let n = Double(window.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var covariance = 0.0
        var variance = 0.0
        for (x, y) in zip(xs, ys) {
            covariance += (x - meanX) * (y - meanY)
            variance += (x - meanX) * (x - meanX)
        }
        return variance > 0 ? covariance / variance : 0
    }

    private func average(of samples: [Sample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        return samples.map(\.level).reduce(0, +) / Double(samples.count)
    }
}
