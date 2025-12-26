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

    var body: some View {
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
    }
}
