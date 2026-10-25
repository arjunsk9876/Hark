//
//  ModelFactsView.swift
//  Hark
//

import SwiftUI

/// Test results shown on the Model facts screen. Replace nil with the real
/// number once a test has been run.
enum MeasuredAccuracy {
    static let results: [(test: String, result: String?)] = [
        ("Accuracy on clean clips", nil),
        ("Accuracy with wind and traffic", nil),
        ("False alarms on a quiet route", nil),
        ("Time from sound to vibration", nil),
        ("Getting closer label", nil),
        ("Battery use per hour", nil),
    ]
}

/// Says plainly which model Hark uses, what it does with audio, the rules it
/// applies, how well it was tested, and what it cannot do.
struct ModelFactsView: View {
    private let settings = UrgencySettings.standard
    private let detectable = AudioClassifier.detectableKinds

    var body: some View {
        List {
            Section("Model") {
                Text("Apple's built-in sound classifier (SoundAnalysis, version 1), trained by Apple. Hark does not train or change it.")
            }

            Section("Privacy") {
                Text("Everything runs on your iPhone. Hark uses no network, no accounts, and no analytics. Audio is never saved or sent. The alert log is kept in memory and is gone when the app closes.")
            }

            Section("Sounds") {
                ForEach(SoundGroup.allCases, id: \.self) { group in
                    let kinds = SoundKind.allCases.filter { $0.group == group }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.title).bold()
                        Text(kinds.map { detectable.contains($0) ? $0.title : "\($0.title) (not yet)" }
                            .joined(separator: ", "))
                    }
                }
                Text("Sounds marked “not yet” have no matching label in Apple's classifier, so Hark cannot hear them.")
                    .foregroundColor(.secondary)
            }

            Section("Rules") {
                Text("Every sound gets an urgency score from 0 to 1, worked out live from:")
                Text(rules)
                Text("No alert below \(format(settings.alertMinimum)). Blue below \(format(settings.mediumUrgency)), orange up to \(format(settings.highUrgency)), red above. Higher scores vibrate harder, with more pulses, more often, and stay on screen longer.")
                Text("“Getting closer” shows for moving sounds when loudness rises faster than \(format(settings.trendRate, digits: 1)) dB per second over \(Int(settings.trendWindow)) seconds.")
            }

            Section("Tested accuracy") {
                ForEach(MeasuredAccuracy.results, id: \.test) { row in
                    HStack {
                        Text(row.test)
                        Spacer()
                        Text(row.result ?? "Not yet measured")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Section("Limits") {
                Text("• It cannot tell which direction a sound came from.")
                Text("• Wind and traffic noise can hide sounds or cause false alerts.")
                Text("• Similar sounds get confused, such as gunshots and fireworks.")
                Text("• Vibration may be weaker or missing with the phone locked.")
                Text("• It does not recognize speech.")
                Text("• \(Copy.safetyNote)")
            }
        }
        .navigationTitle("Model facts")
    }

    private var rules: String {
        [
            ("How dangerous the sound usually is", settings.baseDangerWeight),
            ("Loudness above background noise", settings.loudnessWeight),
            ("How fast it is getting louder", settings.closingWeight),
            ("How suddenly it started", settings.suddennessWeight),
            ("How long it has lasted", settings.persistenceWeight),
            ("How sure the model is", settings.confidenceWeight),
        ]
        .map { "• \($0.0): \(Int(($0.1 * 100).rounded()))%" }
        .joined(separator: "\n")
    }

    private func format(_ value: Double, digits: Int = 2) -> String {
        String(format: "%.\(digits)f", value)
    }
}
