//
//  HiHatPreset.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import Foundation

/// Maps a friendly name to a GM drum kit program and hi-hat note.
struct HiHatPreset: DrumPreset {
    let id: String
    let title: String
    let program: UInt8
    let midiNote: UInt8

    static let all: [HiHatPreset] = [
        // Standard
        .init(id: "std_closed_42", title: "Standard Closed Hi-Hat", program: 0, midiNote: 42),
        .init(id: "std_open_46", title: "Standard Open Hi-Hat", program: 0, midiNote: 46),

        // Room
        .init(id: "room_closed_42", title: "Room Closed Hi-Hat", program: 8, midiNote: 42),
        .init(id: "room_open_46", title: "Room Open Hi-Hat", program: 8, midiNote: 46),

        // Power
        .init(id: "power_closed_42", title: "Power Closed Hi-Hat", program: 16, midiNote: 42),
        .init(id: "power_open_46", title: "Power Open Hi-Hat", program: 16, midiNote: 46),

        // Electronic
        .init(id: "elec_closed_42", title: "Electronic Closed Hi-Hat", program: 24, midiNote: 42),
        .init(id: "elec_open_46", title: "Electronic Open Hi-Hat", program: 24, midiNote: 46),

        // 808/909
        .init(id: "808_closed_42", title: "808 Closed Hi-Hat", program: 25, midiNote: 42),
        .init(id: "909_open_46", title: "909 Open Hi-Hat", program: 25, midiNote: 46),

        // Dance
        .init(id: "dance_closed_42", title: "Dance Closed Hi-Hat", program: 26, midiNote: 42),
        .init(id: "dance_open_46", title: "Dance Open Hi-Hat", program: 26, midiNote: 46),

        // Orchestral
        .init(id: "orch_closed_42", title: "Concert Closed Hi-Hat", program: 48, midiNote: 42),
        .init(id: "orch_open_46", title: "Concert Open Hi-Hat", program: 48, midiNote: 46),
    ]
}
