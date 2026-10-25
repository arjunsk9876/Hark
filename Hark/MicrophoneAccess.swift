//
//  MicrophoneAccess.swift
//  Hark
//

import AVFoundation

/// Whether Hark may use the microphone.
enum MicrophoneAccess {
    case undetermined
    case denied
    case granted

    static var current: MicrophoneAccess {
        if #available(iOS 17, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted: return .granted
            case .denied: return .denied
            default: return .undetermined
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted: return .granted
            case .denied: return .denied
            default: return .undetermined
            }
        }
    }

    /// Shows the system prompt if the user has not answered it yet.
    static func request() async -> MicrophoneAccess {
        guard current == .undetermined else { return current }
        let granted = await withCheckedContinuation { continuation in
            if #available(iOS 17, *) {
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
            }
        }
        return granted ? .granted : .denied
    }
}
