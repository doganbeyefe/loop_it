//
//  SnarePreset.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import Foundation

/// Maps a friendly name to a GM drum kit program and snare note.
struct SnarePreset: DrumPreset {
    let id: String
    let title: String
    let program: UInt8
    let midiNote: UInt8

    static let all: [SnarePreset] = [
        // Standard
        .init(id: "std_38", title: "Standard Snare 1", program: 0, midiNote: 38),
        .init(id: "std_40", title: "Standard Snare 2", program: 0, midiNote: 40),

        // Room
        .init(id: "room_38", title: "Room Snare 1", program: 8, midiNote: 38),
        .init(id: "room_40", title: "Room Snare 2", program: 8, midiNote: 40),

        // Power
        .init(id: "power_38", title: "Power Snare 1", program: 16, midiNote: 38),
        .init(id: "power_40", title: "Power Snare 2", program: 16, midiNote: 40),

        // Electronic
        .init(id: "elec_38", title: "Electronic Snare 1", program: 24, midiNote: 38),
        .init(id: "elec_40", title: "Electronic Snare 2", program: 24, midiNote: 40),

        // 808/909
        .init(id: "808_38", title: "808 Snare", program: 25, midiNote: 38),
        .init(id: "909_40", title: "909 Snare", program: 25, midiNote: 40),

        // Dance
        .init(id: "dance_38", title: "Dance Snare 1", program: 26, midiNote: 38),
        .init(id: "dance_40", title: "Dance Snare 2", program: 26, midiNote: 40),

        // Orchestral
        .init(id: "orch_38", title: "Concert Snare", program: 48, midiNote: 38),
        .init(id: "orch_40", title: "Concert Snare 2", program: 48, midiNote: 40),
    ]
}
