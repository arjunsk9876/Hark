//
//  ContentView.swift
//  Hark
//
//  Created by Arjun SK on 10/25/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var classifier = AudioClassifier()

    private var statusText: String {
        if let sound = classifier.detected { return sound.title }
        return classifier.isListening ? "Listening" : "Stopped"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Text(statusText)
                .font(.system(size: 42, weight: .heavy))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(24)
        }
    }
}

#Preview {
    ContentView()
}
