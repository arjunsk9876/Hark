//
//  AudioClassifier.swift
//  Hark
//

@preconcurrency import AVFoundation
import Combine
@preconcurrency import SoundAnalysis

/// Streams the microphone with AVAudioEngine.
final class AudioClassifier: ObservableObject {
    @Published private(set) var isListening = false

    private let engine = AVAudioEngine()

    func start() throws {
        guard !isListening else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
        try session.setActive(true)

        _ = engine.inputNode
        engine.prepare()
        try engine.start()

        isListening = true
    }

    func stop() {
        guard isListening else { return }
        engine.stop()
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Receives classifier results on the analysis queue and reports the
/// highest-confidence supported sound at 50% confidence or higher.
nonisolated private final class ResultsObserver: NSObject, SNResultsObserving {
    private static let minimumConfidence = 0.5

    // Identifiers from SNClassifySoundRequest version 1.
    private static let labels: [String: SoundKind] = [
        "siren": .siren,
        "police_siren": .siren,
        "ambulance_siren": .siren,
        "fire_engine_siren": .siren,
        "civil_defense_siren": .siren,
        "emergency_vehicle": .siren,
        "car_horn": .carHorn,
        "air_horn": .carHorn,
        "train_horn": .trainHorn,
        "train_whistle": .trainHorn,
        "shout": .shouting,
        "yell": .shouting,
        "screaming": .shouting,
        "vehicle_skidding": .tireScreech,
        "bicycle_bell": .bikeBell,
        "dog_bark": .dogBarking,
        "dog_bow_wow": .dogBarking,
    ]

    private let onDetect: @Sendable (SoundKind) -> Void

    init(onDetect: @escaping @Sendable (SoundKind) -> Void) {
        self.onDetect = onDetect
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        // Classifications are sorted from most to least confident.
        for classification in result.classifications where classification.confidence >= Self.minimumConfidence {
            if let kind = Self.labels[classification.identifier] {
                onDetect(kind)
                return
            }
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("Sound analysis failed: \(error.localizedDescription)")
    }
}
