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

    /// Called on the main actor with the loudness of each buffer, in dBFS.
    var onLoudness: ((Double) -> Void)?

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

        let reportLoudness: @Sendable (Double) -> Void = { [weak self] level in
            guard let self else { return }
            Task { @MainActor in self.onLoudness?(level) }
        }
        input.installTap(onBus: 0, bufferSize: 8192, format: format,
                         block: Self.makeTap(for: analyzer, reportLoudness: reportLoudness))
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
    nonisolated private static func makeTap(
        for analyzer: SNAudioStreamAnalyzer,
        reportLoudness: @escaping @Sendable (Double) -> Void
    ) -> AVAudioNodeTapBlock {
        let queue = DispatchQueue(label: "Hark.analysis")
        return { buffer, time in
            reportLoudness(loudness(of: buffer))
            queue.async {
                analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
        }
    }

    /// Root-mean-square level of the first channel, in dBFS.
    nonisolated private static func loudness(of buffer: AVAudioPCMBuffer) -> Double {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return -100 }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) {
            sum += samples[i] * samples[i]
        }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        return max(-100, 20 * log10(Double(rms)))
    }
}

/// Receives classifier results on the analysis queue and reports the
/// highest-confidence supported sound at 50% confidence or higher.
nonisolated private final class ResultsObserver: NSObject, SNResultsObserving {
    private static let minimumConfidence = 0.5

    // Identifiers from SNClassifySoundRequest version 1.
    // No matching label for: railroad crossing bell, car alarm, burglar alarm,
    // jackhammer, leaf blower, and construction machinery.
    private static let labels: [String: SoundKind] = [
        // Vehicles and traffic
        "siren": .siren,
        "police_siren": .siren,
        "ambulance_siren": .siren,
        "fire_engine_siren": .siren,
        "emergency_vehicle": .siren,
        "car_horn": .carHorn,
        "air_horn": .airHorn,
        "train_horn": .trainHorn,
        "train_whistle": .trainHorn,
        "vehicle_skidding": .tireScreech,
        "reverse_beeps": .backupBeeper,
        "motorcycle": .motorcycle,
        "engine_accelerating_revving": .engineRevving,
        "truck": .truckOrBus,
        "bus": .truckOrBus,
        "car_passing_by": .carPassing,
        "bicycle_bell": .bikeBell,
        "skateboard": .skateboard,

        // Alarms and warnings
        "smoke_detector": .smokeAlarm,
        "civil_defense_siren": .civilDefenseSiren,
        "whistling": .whistle,

        // People
        "screaming": .screaming,
        "shout": .shouting,
        "yell": .shouting,
        "baby_crying": .babyCrying,

        // Sudden events
        "gunshot_gunfire": .gunshot,
        "artillery_fire": .gunshot,
        "boom": .explosion,
        "fireworks": .fireworks,
        "firecracker": .fireworks,
        "glass_breaking": .glassBreaking,
        "thump_thud": .crash,

        // Animals
        "dog_bark": .dogBarking,
        "dog_bow_wow": .dogBarking,
        "dog_growl": .dogGrowling,

        // Weather
        "thunder": .thunder,
        "thunderstorm": .thunder,

        // Machinery
        "chainsaw": .chainsaw,
        "drill": .powerTool,
        "power_tool": .powerTool,
        "lawn_mower": .lawnMower,
        "helicopter": .helicopter,
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
