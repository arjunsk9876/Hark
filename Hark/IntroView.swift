//
//  IntroView.swift
//  Hark
//

import SwiftUI

/// Shown once, before the microphone prompt.
struct IntroView: View {
    let onContinue: () async -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 90
    @ScaledMetric(relativeTo: .largeTitle) private var nameSize = 42
    @State private var isContinuing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "ear.fill")
                    .font(.system(size: iconSize, weight: .bold))
                    .accessibilityHidden(true)
                Text("Hark")
                    .font(.system(size: nameSize, weight: .heavy))
                Text("Hark listens for traffic and warning sounds and tells you with color, words, and vibration. It needs the microphone. Audio stays on your iPhone and is never saved or sent.")
                    .font(.title3)
                Text(Copy.safetyNote)
                    .font(.title3.weight(.bold))
                Spacer()
                Button("Continue") {
                    isContinuing = true
                    Task { await onContinue() }
                }
                .buttonStyle(SolidButtonStyle())
                .disabled(isContinuing)
            }
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(24)
        }
    }
}
