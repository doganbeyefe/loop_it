//
//  KickPatternRow.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import Foundation

/// Represents a single pattern row with steps and a playback speed multiplier.
struct KickPatternRow: Identifiable, Equatable {
    let id = UUID()
    var steps: [Bool] = [false, false, false, false]
    var speed: Double = 1.0
    var repeatCount: Int = 1
}
