//
//  AudioClassifier.swift
//  Hark
//

@preconcurrency import AVFoundation
@preconcurrency import SoundAnalysis

/// One supported sound the classifier heard, with how sure it is.
nonisolated struct Detection: Sendable {
    let kind: SoundKind
    let confidence: Double
}

/// One raw classifier label, supported or not, for the debug view.
nonisolated struct HeardLabel: Sendable, Identifiable {
    let identifier: String
    let confidence: Double
    let kind: SoundKind?

    var id: String { identifier }
}

/// Streams the microphone into Apple's built-in sound classifier and
/// reports loudness and supported sounds through callbacks.
final class AudioClassifier {
    /// Whether the engine is running right now.
    private(set) var isListening = false

    /// Whether the user wants to listen. Stays true through interruptions
    /// such as a phone call, so listening can resume afterwards.
    private(set) var wantsToListen = false

    /// Called on the main actor with the loudness of each buffer, in dBFS.
    var onLoudness: ((Double) -> Void)?

    /// Called on the main actor with every supported sound in each result.
    var onDetections: (([Detection]) -> Void)?

    /// Called on the main actor with the top raw labels in each result.
    var onHeard: (([HeardLabel]) -> Void)?

    /// Called on the main actor when listening pauses (true) or resumes (false)
    /// on its own, for example around a phone call.
    var onPauseChange: ((Bool) -> Void)?

    /// Sounds that have a matching label in the built-in classifier.
    static var detectableKinds: Set<SoundKind> {
        Set(ResultsObserver.labels.values)
    }

    private var engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private var observer: ResultsObserver?
    private var notificationTokens: [NSObjectProtocol] = []

    init() {
        observeSession()
    }

    func start() throws {
        wantsToListen = true
        do {
            try startEngine()
        } catch {
            wantsToListen = false
            throw error
        }
    }

    func stop() {
        wantsToListen = false
        stopEngine()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Starts again after an interruption, if the user still wants to listen.
    /// Safe to call at any time, such as when the app comes back on screen.
    func resumeIfNeeded() {
        guard wantsToListen, !isListening else { return }
        do {
            try startEngine()
            onPauseChange?(false)
        } catch {
            onPauseChange?(true)
        }
    }

    private func startEngine() throws {
        guard !isListening else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        let analyzer = SNAudioStreamAnalyzer(format: format)
        let observer = ResultsObserver(
            minimumConfidence: UrgencySettings.standard.minimumConfidence,
            onDetect: { [weak self] detections in
                guard let self else { return }
                Task { @MainActor in self.onDetections?(detections) }
            },
            onHeard: { [weak self] heard in
                guard let self else { return }
                Task { @MainActor in self.onHeard?(heard) }
            }
        )
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        try analyzer.add(request, withObserver: observer)

        let reportLoudness: @Sendable (Double) -> Void = { [weak self] level in
            guard let self else { return }
            Task { @MainActor in self.onLoudness?(level) }
        }
        input.installTap(onBus: 0, bufferSize: 8192, format: format,
                         block: Self.makeTap(for: analyzer, reportLoudness: reportLoudness))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }

        self.analyzer = analyzer
        self.observer = observer
        isListening = true
    }

    private func stopEngine() {
        guard isListening else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        analyzer?.removeAllRequests()
        analyzer = nil
        observer = nil
        isListening = false
    }

    /// Pauses for phone calls and Siri, restarts after headphones connect or
    /// disconnect, and rebuilds the engine if iOS resets its audio services.
    private func observeSession() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        notificationTokens.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: session, queue: .main
        ) { [weak self] note in
            let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated {
                guard let self, let rawType,
                      let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
                switch type {
                case .began:
                    guard self.isListening else { return }
                    self.stopEngine()
                    self.onPauseChange?(true)
                case .ended:
                    self.resumeIfNeeded()
                @unknown default:
                    break
                }
            }
        })

        notificationTokens.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // The old engine is unusable after a reset, so make a new one.
                self.isListening = false
                self.analyzer = nil
                self.observer = nil
                self.engine = AVAudioEngine()
                self.resumeIfNeeded()
            }
        })

        notificationTokens.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
        ) { [weak self] note in
            let changed = note.object as AnyObject?
            MainActor.assumeIsolated {
                guard let self, changed === self.engine, self.wantsToListen else { return }
                // The input format may have changed, so rebuild the tap.
                self.stopEngine()
                self.resumeIfNeeded()
            }
        })
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

/// Receives classifier results on the analysis queue and reports every
/// supported sound at or above the minimum confidence, most confident first.
nonisolated private final class ResultsObserver: NSObject, SNResultsObserving {
    // Identifiers from SNClassifySoundRequest version 1.
    // No matching label for: railroad crossing bell, car alarm, burglar alarm,
    // jackhammer, leaf blower, and construction machinery.
    static let labels: [String: SoundKind] = [
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

    // How many raw labels the debug view shows.
    private static let heardCount = 5

    private let minimumConfidence: Double
    private let onDetect: @Sendable ([Detection]) -> Void
    private let onHeard: @Sendable ([HeardLabel]) -> Void

    init(
        minimumConfidence: Double,
        onDetect: @escaping @Sendable ([Detection]) -> Void,
        onHeard: @escaping @Sendable ([HeardLabel]) -> Void
    ) {
        self.minimumConfidence = minimumConfidence
        self.onDetect = onDetect
        self.onHeard = onHeard
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }

        onHeard(result.classifications.prefix(Self.heardCount).map {
            HeardLabel(identifier: $0.identifier, confidence: $0.confidence, kind: Self.labels[$0.identifier])
        })

        // Classifications are sorted from most to least confident, so the
        // first label seen for each sound is its best one.
        var detections: [Detection] = []
        for classification in result.classifications where classification.confidence >= minimumConfidence {
            if let kind = Self.labels[classification.identifier],
               !detections.contains(where: { $0.kind == kind }) {
                detections.append(Detection(kind: kind, confidence: classification.confidence))
            }
        }
        if !detections.isEmpty {
            onDetect(detections)
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("Sound analysis failed: \(error.localizedDescription)")
    }
}
