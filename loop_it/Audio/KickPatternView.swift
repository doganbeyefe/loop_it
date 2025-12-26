//
//  KickPatternView.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import SwiftUI

struct KickPatternView: View {
    @Binding var steps: [Bool]   // expects 4 items

    var body: some View {
        HStack(spacing: 12) {
            ForEach(steps.indices, id: \.self) { i in
                Button {
                    steps[i].toggle()
                } label: {
                    Image(systemName: steps[i] ? "checkmark.square.fill" : "square")
                        .font(.system(size: 28))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Step \(i + 1)")
            }
        }
    }
}
