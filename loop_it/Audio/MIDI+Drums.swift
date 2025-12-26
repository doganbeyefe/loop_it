//
//  MIDI+Drums.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import Foundation

// General MIDI drum channel is 10 => index 9 in CoreMIDI/AVAudioUnitSampler.
let GM_DRUM_CHANNEL: UInt8 = 9

enum DrumKit: Identifiable, CaseIterable, Hashable {
    case standard1, standard2, standard3
    case room, power, electronic, kit808_909, dance
    case jazz, brush, orchestral, sfx

    var id: Self { self }

    /// Program Change (PC) values for Drum Kits in the GeneralUser GS docs.
    var program: UInt8 {
        switch self {
        case .standard1:  return 0
        case .standard2:  return 1
        case .standard3:  return 2
        case .room:       return 8
        case .power:      return 16
        case .electronic: return 24
        case .kit808_909: return 25
        case .dance:      return 26
        case .jazz:       return 32
        case .brush:      return 40
        case .orchestral: return 48
        case .sfx:        return 56
        }
    }

    var title: String {
        switch self {
        case .standard1:  return "Standard 1"
        case .standard2:  return "Standard 2"
        case .standard3:  return "Standard 3"
        case .room:       return "Room"
        case .power:      return "Power"
        case .electronic: return "Electronic"
        case .kit808_909: return "808/909"
        case .dance:      return "Dance"
        case .jazz:       return "Jazz"
        case .brush:      return "Brush"
        case .orchestral: return "Orchestral"
        case .sfx:        return "SFX"
        }
    }
}

enum KickSlot: Identifiable, CaseIterable, Hashable {
    case kick2_B0   // MIDI 35
    case kick1_C1   // MIDI 36

    var id: Self { self }

    var midiNote: UInt8 {
        switch self {
        case .kick2_B0: return 35
        case .kick1_C1: return 36
        }
    }

    /// Kit-aware label (because the same note is named differently in different kits)
    func label(for kit: DrumKit) -> String {
        switch (kit, self) {
        case (.kit808_909, .kick2_B0): return "808 Bass Drum (B0 / 35)"
        case (.kit808_909, .kick1_C1): return "909 Bass Drum (C1 / 36)"
        case (.room, .kick1_C1):       return "Room Kick (C1 / 36)"
        case (.power, .kick1_C1):      return "Power Kick 1 (C1 / 36)"
        case (.power, .kick2_B0):      return "Power Kick 2 (B0 / 35)"
        case (.electronic, .kick1_C1): return "Elec BD (C1 / 36)"
        default:
            return self == .kick1_C1 ? "Kick 1 (C1 / 36)" : "Kick 2 (B0 / 35)"
        }
    }
}
