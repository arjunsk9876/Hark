//
//  RecentView.swift
//  Hark
//

import SwiftUI

/// The last alerts, newest first. They are lost when the app closes.
struct RecentView: View {
    @ObservedObject var alerts: AlertController

    var body: some View {
        List {
            if alerts.recent.isEmpty {
                Text("No alerts yet")
                    .foregroundColor(.secondary)
            }
            ForEach(alerts.recent) { entry in
                HStack(spacing: 16) {
                    Image(systemName: entry.kind.symbol)
                        .font(.title2.weight(.bold))
                        .foregroundColor(entry.level.textColor)
                        .frame(width: 52, height: 52)
                        .background(entry.level.color)
                        .cornerRadius(10)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.kind.title)
                            .font(.title3.weight(.heavy))
                        Text("\(entry.level.title) urgency")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(entry.time, style: .time)
                        .font(.body.monospacedDigit())
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
        }
        .navigationTitle("Recent")
    }
}
