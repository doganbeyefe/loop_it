//
//  KickPatternView.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import SwiftUI

/// Simple 4-step toggle UI for a kick pattern.
struct KickPatternView: View {
    @Binding var steps: [Bool] // expects 4 items

    var body: some View {
        HStack(spacing: 12) {
            ForEach(steps.indices, id: \.self) { index in
                let isOn = steps[index]
                Button {
                    steps[index].toggle()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isOn ? Color.accentColor : Color(.secondarySystemFill))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(isOn ? 0.25 : 0.12), radius: 4, x: 0, y: 2)

                        Circle()
                            .fill(isOn ? Color.white.opacity(0.35) : Color.black.opacity(0.12))
                            .frame(width: 12, height: 12)
                            .offset(x: 10, y: -10)
                    }
                    .frame(width: 44, height: 44)
                    .scaleEffect(isOn ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Step \(index + 1)")
                .accessibilityValue(isOn ? "On" : "Off")
            }
        }
    }
}
