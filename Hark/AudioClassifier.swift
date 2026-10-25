//
//  AudioClassifier.swift
//  Hark
//

@preconcurrency import AVFoundation
import Combine
@preconcurrency import SoundAnalysis

/// Streams the microphone into Apple's built-in sound classifier and
/// publishes the latest supported sound it hears.
final class AudioClassifier: ObservableObject {
    @Published private(set) var detected: SoundKind?
    @Published private(set) var isListening = false

    private let engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private var observer: ResultsObserver?

    func start() throws {
        guard !isListening else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        let analyzer = SNAudioStreamAnalyzer(format: format)
        let observer = ResultsObserver { [weak self] kind in
            guard let self else { return }
            Task { @MainActor in self.detected = kind }
        }
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        try analyzer.add(request, withObserver: observer)

        input.installTap(onBus: 0, bufferSize: 8192, format: format, block: Self.makeTap(for: analyzer))
        engine.prepare()
        try engine.start()

        self.analyzer = analyzer
        self.observer = observer
        isListening = true
    }

    func stop() {
        guard isListening else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        analyzer?.removeAllRequests()
        analyzer = nil
        observer = nil
        detected = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // Built outside the main actor because the audio thread calls it.
    nonisolated private static func makeTap(for analyzer: SNAudioStreamAnalyzer) -> AVAudioNodeTapBlock {
        let queue = DispatchQueue(label: "Hark.analysis")
        return { buffer, time in
            queue.async {
                analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
        }
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
