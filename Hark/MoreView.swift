//
//  MoreView.swift
//  Hark
//

import SwiftUI

/// Settings and info that are not needed during a run.
struct MoreView: View {
    @ObservedObject var alerts: AlertController
    @AppStorage("showDebug") private var showDebug = false

    var body: some View {
        List {
            Section {
                Toggle("Keep screen on", isOn: $alerts.keepScreenOn)
            } footer: {
                Text("Stops the screen from locking while Hark is listening.")
            }

            Section {
                NavigationLink("Model facts") {
                    ModelFactsView()
                }
            }

            Section {
                Toggle("Debug", isOn: $showDebug)
            } footer: {
                Text("Shows what the model hears, how sure it is, and the urgency score with each signal on the main screen.")
            }

            Section("Safety") {
                Text(Copy.safetyNote)
            }
        }
        .font(.title3)
        .navigationTitle("More")
    }
}
