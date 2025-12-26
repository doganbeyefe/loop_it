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
                Button {
                    steps[index].toggle()
                } label: {
                    Image(systemName: steps[index] ? "checkmark.square.fill" : "square")
                        .font(.system(size: 28))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Step \(index + 1)")
            }
        }
    }
}
