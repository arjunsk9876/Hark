//
//  AlertController.swift
//  Hark
//

import Combine
import Foundation
import UIKit

/// The sound currently shown on screen.
struct Alert {
    let kind: SoundKind
    let score: Double
    let level: UrgencyLevel
    let trend: Trend
    let signals: UrgencySignals
    let decibelsAboveBackground: Double
    let decibelsPerSecond: Double
}

/// One past alert on the Recent screen, with the highest score it reached.
struct LoggedAlert: Identifiable {
    let id = UUID()
    let kind: SoundKind
    let time: Date
    var score: Double
    var level: UrgencyLevel
}

/// Turns classifier detections and loudness into scored alerts.
final class AlertController: ObservableObject {
    @Published private(set) var alert: Alert?
    @Published private(set) var isListening = false
    @Published private(set) var isPaused = false

    /// Recent alerts, newest first. Kept in memory only.
    @Published private(set) var recent: [LoggedAlert] = []

    /// What the classifier heard most recently, and how each supported sound
    /// in it scored, for the debug view.
    @Published private(set) var heard: [HeardLabel] = []
    @Published private(set) var scored: [Alert] = []

    @Published var keepScreenOn: Bool {
        didSet {
            UserDefaults.standard.set(keepScreenOn, forKey: Self.keepScreenOnKey)
            updateIdleTimer()
        }
    }

    private static let keepScreenOnKey = "keepScreenOn"

    private let settings = UrgencySettings.standard
    private let classifier = AudioClassifier()
    private let haptics = Haptics()
    private var loudness = LoudnessTracker(settings: .standard)
    private var firstHeard: [SoundKind: Date] = [:]
    private var lastHeard: [SoundKind: Date] = [:]
    private var clearTask: Task<Void, Never>?
    private var lastBuzz: Date?

    init() {
        keepScreenOn = UserDefaults.standard.bool(forKey: Self.keepScreenOnKey)
        classifier.onLoudness = { [weak self] level in
            self?.loudness.add(level, at: Date())
        }
        classifier.onDetections = { [weak self] detections in
            self?.handle(detections, at: Date())
        }
        classifier.onHeard = { [weak self] heard in
            self?.heard = heard
        }
        classifier.onPauseChange = { [weak self] paused in
            self?.setPaused(paused)
        }
    }

    func start() throws {
        try classifier.start()
        isListening = true
        isPaused = false
        updateIdleTimer()
    }

    func stop() {
        classifier.stop()
        isListening = false
        isPaused = false
        reset()
        updateIdleTimer()
    }

    /// Tries to restart listening after an interruption, such as when the
    /// app comes back on screen after a call.
    func resumeIfNeeded() {
        classifier.resumeIfNeeded()
    }

    private func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused {
            reset()
        }
    }

    private func reset() {
        clearTask?.cancel()
        alert = nil
        lastBuzz = nil
        heard = []
        scored = []
        loudness.reset()
        firstHeard.removeAll()
        lastHeard.removeAll()
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenOn && isListening
    }

    private func handle(_ detections: [Detection], at now: Date) {
        let all = detections.map { score($0, at: now) }
        scored = all
        let candidates = all.filter { $0.score >= settings.alertMinimum }
        guard let best = candidates.max(by: { $0.score < $1.score }) else { return }

        // A lower-scoring sound never replaces a different sound on screen.
        if let current = alert, current.kind != best.kind, best.score < current.score {
            return
        }
        let isNewSound = alert?.kind != best.kind
        alert = best
        log(best, isNewSound: isNewSound, at: now)
        scheduleClear(after: settings.holdTime(for: best.score))
        buzzIfDue(for: best, isNewSound: isNewSound, at: now)
    }

    /// Adds a new sound to the log, or raises the score of the one on screen.
    private func log(_ alert: Alert, isNewSound: Bool, at now: Date) {
        if !isNewSound, let latest = recent.first, latest.kind == alert.kind {
            if alert.score > latest.score {
                recent[0].score = alert.score
                recent[0].level = alert.level
            }
            return
        }
        recent.insert(LoggedAlert(kind: alert.kind, time: now, score: alert.score, level: alert.level), at: 0)
        if recent.count > settings.recentLimit {
            recent.removeLast(recent.count - settings.recentLimit)
        }
        if isNewSound {
            UIAccessibility.post(notification: .announcement, argument: alert.kind.title)
        }
    }

    /// Buzzes at once for a new sound, then repeats while it continues.
    /// Higher scores buzz harder, sharper, with more pulses, and more often.
    private func buzzIfDue(for alert: Alert, isNewSound: Bool, at now: Date) {
        if !isNewSound, let lastBuzz,
           now.timeIntervalSince(lastBuzz) < settings.repeatInterval(for: alert.score) {
            return
        }
        haptics.buzz(
            intensity: settings.vibrationIntensity(for: alert.score),
            sharpness: settings.vibrationSharpness(for: alert.score),
            pulses: settings.pulses(for: alert.level)
        )
        lastBuzz = now
    }

    /// Clears the alert once no new detection has arrived for `seconds`.
    private func scheduleClear(after seconds: Double) {
        clearTask?.cancel()
        clearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.alert = nil
            self?.lastBuzz = nil
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
        let aboveBackground = loudness.aboveBackground(at: now)

        let signals = UrgencySignals(
            kind: kind,
            confidence: detection.confidence,
            decibelsAboveBackground: aboveBackground,
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
            signals: signals,
            decibelsAboveBackground: aboveBackground,
            decibelsPerSecond: trend
        )
    }
}
