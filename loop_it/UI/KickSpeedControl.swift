//
//  KickSpeedControl.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import SwiftUI

/// UI control for speeding up or slowing down a kick pattern row.
struct KickSpeedControl: View {
    @Binding var speed: Double
    @Binding var repeatCount: Int
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Button("/2") {
                    speed = max(speed / 2.0, 0.25)
                }
                .buttonStyle(.bordered)

                Text("speed: \(speed.cleanSpeedText)")
                    .font(.subheadline)
                    .monospacedDigit()

                Button("x2") {
                    speed = min(speed * 2.0, 8.0)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                Button("-1") {
                    repeatCount = max(repeatCount - 1, 1)
                }
                .buttonStyle(.bordered)

                Text("repeat: \(repeatCount)")
                    .font(.subheadline)
                    .monospacedDigit()

                Button("+1") {
                    repeatCount = min(repeatCount + 1, 8)
                }
                .buttonStyle(.bordered)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Delete pattern row")
            }
        }
    }
}
