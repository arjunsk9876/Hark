//
//  ContentView.swift
//  Hark
//
//  Created by Arjun SK on 10/25/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var classifier = AudioClassifier()
    @State private var errorMessage: String?

    private var statusText: String {
        if let errorMessage { return errorMessage }
        if let sound = classifier.detected { return sound.title }
        return classifier.isListening ? "Listening" : "Stopped"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Text(statusText)
                    .font(.system(size: 42, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Spacer()

                Button(action: toggleListening) {
                    Text(classifier.isListening ? "Stop" : "Start")
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
    }

    private func toggleListening() {
        errorMessage = nil
        if classifier.isListening {
            classifier.stop()
        } else {
            do {
                try classifier.start()
            } catch {
                errorMessage = "Could not start microphone"
            }
        }
    }
}

#Preview {
    ContentView()
}
