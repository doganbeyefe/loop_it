//
//  KickPreset.swift.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import Foundation

/// Maps a friendly name to a GM drum kit program and kick note.
struct KickPreset: DrumPreset {
    let id: String
    let title: String
    let program: UInt8   // drum kit program in the SF2
    let midiNote: UInt8  // 35 or 36

    static let all: [KickPreset] = [
        // Standard
        .init(id: "std1_36", title: "Standard Kick 1", program: 0, midiNote: 36),
        .init(id: "std1_35", title: "Standard Kick 2", program: 0, midiNote: 35),

        // Room
        .init(id: "room_36", title: "Room Kick", program: 8, midiNote: 36),
        .init(id: "room_35", title: "Room Kick 2", program: 8, midiNote: 35),

        // Power
        .init(id: "power_36", title: "Power Kick 1", program: 16, midiNote: 36),
        .init(id: "power_35", title: "Power Kick 2", program: 16, midiNote: 35),

        // Electronic
        .init(id: "elec_36", title: "Electronic Kick", program: 24, midiNote: 36),
        .init(id: "elec_35", title: "Electronic Kick 2", program: 24, midiNote: 35),

        // 808/909
        .init(id: "808_35", title: "808 Kick", program: 25, midiNote: 35),
        .init(id: "909_36", title: "909 Kick", program: 25, midiNote: 36),

        // Dance
        .init(id: "dance_36", title: "Dance Kick", program: 26, midiNote: 36),
        .init(id: "dance_35", title: "Dance Kick 2", program: 26, midiNote: 35),

        // Orchestral
        .init(id: "orch_36", title: "Concert Bass Drum", program: 48, midiNote: 36),
        .init(id: "orch_35", title: "Concert Bass Drum 2", program: 48, midiNote: 35),
    ]
}
