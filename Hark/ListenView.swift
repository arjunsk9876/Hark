//
//  ListenView.swift
//  Hark
//

import SwiftUI

/// The main screen. It only says what is happening right now.
struct ListenView: View {
    @ObservedObject var alerts: AlertController
    @Binding var micAccess: MicrophoneAccess
    @AppStorage("showDebug") private var showDebug = false
    @State private var errorMessage: String?
    @Environment(\.openURL) private var openURL

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 110
    @ScaledMetric(relativeTo: .largeTitle) private var nameSize = 42
    @ScaledMetric(relativeTo: .title) private var trendSize = 28

    private var level: UrgencyLevel? {
        micAccess == .denied ? nil : alerts.alert?.level
    }

    private var backgroundColor: Color {
        level?.color ?? .black
    }

    private var textColor: Color {
        level?.textColor ?? .white
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                center
                if showDebug && micAccess != .denied {
                    DebugPanel(alerts: alerts)
                }
                Spacer()
                if micAccess != .denied {
                    Button(alerts.isListening ? "Stop" : "Start", action: toggleListening)
                        .buttonStyle(SolidButtonStyle())
                }
                links
            }
            .padding(24)
        }
        .animation(.easeInOut(duration: 0.15), value: level)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var center: some View {
        if micAccess == .denied {
            VStack(spacing: 20) {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: iconSize * 0.7, weight: .bold))
                    .accessibilityHidden(true)
                Text(Copy.micOff)
                    .font(.system(size: nameSize, weight: .heavy))
                Text(Copy.micOffDetail)
                    .font(.body)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(SolidButtonStyle())
            }
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: iconSize, weight: .bold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: nameSize, weight: .heavy))
                if let detail {
                    Text(detail)
                        .font(.system(size: trendSize, weight: .bold))
                }
            }
            .foregroundColor(textColor)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
            .accessibilityElement(children: .combine)
        }
    }

    private var links: some View {
        HStack {
            NavigationLink {
                RecentView(alerts: alerts)
            } label: {
                Text("Recent").underline()
                    .frame(minWidth: 60, minHeight: 44)
            }
            Spacer()
            NavigationLink {
                MoreView(alerts: alerts)
            } label: {
                Text("More").underline()
                    .frame(minWidth: 60, minHeight: 44)
            }
        }
        .font(.title3.weight(.semibold))
        .foregroundColor(textColor)
    }

    private var symbol: String {
        if errorMessage != nil { return "exclamationmark.triangle.fill" }
        if let alert = alerts.alert { return alert.kind.symbol }
        if alerts.isPaused { return "pause.circle.fill" }
        return alerts.isListening ? "ear.fill" : "ear"
    }

    private var title: String {
        if let errorMessage { return errorMessage }
        if let alert = alerts.alert { return alert.kind.title }
        if alerts.isPaused { return "Paused" }
        return alerts.isListening ? "Listening" : "Stopped"
    }

    private var detail: String? {
        if errorMessage != nil { return nil }
        if let alert = alerts.alert {
            switch alert.trend {
            case .closer: return "Getting closer"
            case .away: return "Moving away"
            case .steady: return nil
            }
        }
        if alerts.isPaused { return "Resumes after the call or interruption" }
        return nil
    }

    private func toggleListening() {
        errorMessage = nil
        if alerts.isListening {
            alerts.stop()
            return
        }
        Task {
            micAccess = await MicrophoneAccess.request()
            guard micAccess == .granted else { return }
            do {
                try alerts.start()
            } catch {
                errorMessage = "Could not start microphone"
            }
        }
    }
}

/// What the model hears, how sure it is, and why an alert fired.
struct DebugPanel: View {
    @ObservedObject var alerts: AlertController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Heard").bold()
            if alerts.heard.isEmpty {
                Text("Nothing yet")
            }
            ForEach(alerts.heard) { label in
                Text("\(label.kind == nil ? "  " : "• ")\(label.identifier) \(percent(label.confidence))")
            }

            if let shown = alerts.alert ?? alerts.scored.max(by: { $0.score < $1.score }) {
                Divider().background(Color.white)
                Text("\(shown.kind.title): \(format(shown.score)) \(UrgencyLevel(score: shown.score, settings: .standard).title)")
                    .bold()
                let s = shown.signals
                Text("danger \(format(s.baseDanger))  loud \(format(s.loudness))  closing \(format(s.closing))")
                Text("sudden \(format(s.suddenness))  lasting \(format(s.persistence))  sure \(format(s.confidence))")
                Text(String(format: "%+.1f dB over background, %+.1f dB/s", shown.decibelsAboveBackground, shown.decibelsPerSecond))
            }
        }
        .font(.caption.monospaced())
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black)
        .cornerRadius(8)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
