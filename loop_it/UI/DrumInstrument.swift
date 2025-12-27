//
//  DrumInstrument.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import Foundation

enum DrumInstrument: String, CaseIterable, Identifiable {
    case kick
    case snare
    case hiHat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kick:
            return "Kick"
        case .snare:
            return "Snare"
        case .hiHat:
            return "Hi-Hat"
        }
    }

    var systemImage: String {
        switch self {
        case .kick:
            return "circle.fill"
        case .snare:
            return "burst.fill"
        case .hiHat:
            return "waveform.path"
        }
    }
}
