//
//  ContentView.swift
//  Hark
//
//  Created by Arjun SK on 10/25/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var alerts = AlertController()
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false
    @State private var micAccess = MicrophoneAccess.current

    var body: some View {
        Group {
            if hasSeenIntro {
                NavigationStack {
                    ListenView(alerts: alerts, micAccess: $micAccess)
                }
            } else {
                IntroView {
                    micAccess = await MicrophoneAccess.request()
                    hasSeenIntro = true
                }
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // The user may have changed the permission in Settings, or a call
            // may have ended while the app was away.
            micAccess = MicrophoneAccess.current
            alerts.resumeIfNeeded()
        }
    }
}

#Preview {
    ContentView()
}
