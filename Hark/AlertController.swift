//
//  AlertController.swift
//  Hark
//

import Combine
import Foundation

/// The sound currently shown on screen.
struct Alert {
    let kind: SoundKind
    let score: Double
    let level: UrgencyLevel
    let trend: Trend
    let signals: UrgencySignals
}

/// Turns classifier detections and loudness into scored alerts.
final class AlertController: ObservableObject {
    @Published private(set) var alert: Alert?
    @Published private(set) var isListening = false

    private let settings = UrgencySettings.standard
    private let classifier = AudioClassifier()
    private var loudness = LoudnessTracker(settings: .standard)
    private var firstHeard: [SoundKind: Date] = [:]
    private var lastHeard: [SoundKind: Date] = [:]
    private var clearTask: Task<Void, Never>?

    init() {
        classifier.onLoudness = { [weak self] level in
            self?.loudness.add(level, at: Date())
        }
        classifier.onDetections = { [weak self] detections in
            self?.handle(detections, at: Date())
        }
    }

    func start() throws {
        try classifier.start()
        isListening = true
    }

    func stop() {
        classifier.stop()
        isListening = false
        clearTask?.cancel()
        alert = nil
        loudness.reset()
        firstHeard.removeAll()
        lastHeard.removeAll()
    }

    private func handle(_ detections: [Detection], at now: Date) {
        let candidates = detections
            .map { score($0, at: now) }
            .filter { $0.score >= settings.alertMinimum }
        guard let best = candidates.max(by: { $0.score < $1.score }) else { return }

        // A lower-scoring sound never replaces a different sound on screen.
        if let current = alert, current.kind != best.kind, best.score < current.score {
            return
        }
        alert = best
        scheduleClear(after: settings.holdTime(for: best.score))
    }

    /// Clears the alert once no new detection has arrived for `seconds`.
    private func scheduleClear(after seconds: Double) {
        clearTask?.cancel()
        clearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.alert = nil
        }
    }

    private func score(_ detection: Detection, at now: Date) -> Alert {
        let kind = detection.kind
        if let last = lastHeard[kind], now.timeIntervalSince(last) <= settings.longestHold {
            lastHeard[kind] = now
        } else {
            firstHeard[kind] = now
            lastHeard[kind] = now
        }
        let secondsHeard = now.timeIntervalSince(firstHeard[kind] ?? now)
        let trend = loudness.trend(at: now)

        let signals = UrgencySignals(
            kind: kind,
            confidence: detection.confidence,
            decibelsAboveBackground: loudness.aboveBackground(at: now),
            trend: trend,
            suddenRise: loudness.suddenRise(at: now),
            secondsHeard: secondsHeard,
            settings: settings
        )
        let score = signals.score(with: settings)
        return Alert(
            kind: kind,
            score: score,
            level: UrgencyLevel(score: score, settings: settings),
            trend: Trend(kind: kind, decibelsPerSecond: trend, settings: settings),
            signals: signals
        )
    }
}
