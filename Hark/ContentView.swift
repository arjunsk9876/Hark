//
//  ContentView.swift
//  Hark
//
//  Created by Arjun SK on 10/25/26.
//

import Combine
import SwiftUI

struct ContentView: View {
    @StateObject private var alerts = AlertController()
    @State private var errorMessage: String?

    private var statusText: String {
        if let errorMessage { return errorMessage }
        if let alert = alerts.alert { return alert.kind.title }
        return alerts.isListening ? "Listening" : "Stopped"
    }

    private var trendText: String? {
        guard errorMessage == nil else { return nil }
        switch alerts.alert?.trend {
        case .closer: return "Getting closer"
        case .away: return "Moving away"
        case .steady, nil: return nil
        }
    }

    private var backgroundColor: Color {
        switch alerts.alert?.level {
        case nil: return .black
        case .low: return Color(.systemBlue)
        case .medium: return Color(.systemOrange)
        case .high: return Color(.systemRed)
        }
    }

    // White on orange is hard to read, so orange alerts use black text.
    private var textColor: Color {
        alerts.alert?.level == .medium ? .black : .white
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 12) {
                    Text(statusText)
                        .font(.system(size: 42, weight: .heavy))

                    if let trendText {
                        Text(trendText)
                            .font(.system(size: 28, weight: .bold))
                    }
                }
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)

                Spacer()

                Button(action: toggleListening) {
                    Text(alerts.isListening ? "Stop" : "Start")
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(Color(white: 0.2))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        // Vibrate once each time a new sound is detected.
        .onReceive(alerts.$alert.map { $0?.kind }.removeDuplicates().compactMap { $0 }) { _ in
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func toggleListening() {
        errorMessage = nil
        if alerts.isListening {
            alerts.stop()
        } else {
            do {
                try alerts.start()
            } catch {
                errorMessage = "Could not start microphone"
            }
        }
    }
}

#Preview {
    ContentView()
}
