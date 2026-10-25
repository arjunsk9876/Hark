//
//  Styles.swift
//  Hark
//

import SwiftUI

/// Words shown in more than one place.
enum Copy {
    static let safetyNote = "Hark is an aid, not a replacement for awareness. It can miss sounds, so keep watching your surroundings."
    static let micOff = "Microphone is off"
    static let micOffDetail = "Hark needs the microphone to hear traffic and warning sounds. Turn it on in Settings."
}

extension UrgencyLevel {
    var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var color: Color {
        switch self {
        case .low: return Color(.systemBlue)
        case .medium: return Color(.systemOrange)
        case .high: return Color(.systemRed)
        }
    }

    // White on orange is hard to read, so orange alerts use black text.
    var textColor: Color {
        self == .medium ? .black : .white
    }
}

/// The main solid button: dark gray, white text, at least 60 pt tall.
struct SolidButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title.weight(.bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color(white: configuration.isPressed ? 0.3 : 0.2))
            .cornerRadius(12)
    }
}
