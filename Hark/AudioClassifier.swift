//
//  AudioClassifier.swift
//  Hark
//

@preconcurrency import AVFoundation
import Combine

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
