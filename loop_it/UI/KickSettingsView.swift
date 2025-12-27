//
//  KickSettingsView.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import SwiftUI

struct KickSettingsView: View {
    @ObservedObject var audio: SoundFontKickEngine
    let instanceID: InstrumentInstanceID = InstrumentInstanceID(instrument: .kick)
    let instrument: DrumInstrument = .kick
    @State private var selectedPreset: KickPreset = KickPreset.all[0]

    var body: some View {
        VStack(spacing: 16) {
            Picker("Kick", selection: $selectedPreset) {
                ForEach(KickPreset.all) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedPreset) { _, newPreset in
                audio.setPreset(
                    for: instanceID,
                    instrument: instrument,
                    program: newPreset.program,
                    midiNote: newPreset.midiNote
                )
            }

            Button("Preview Kick") {
                audio.setPreset(
                    for: instanceID,
                    instrument: instrument,
                    program: selectedPreset.program,
                    midiNote: selectedPreset.midiNote
                )
                audio.playPreview(for: instanceID)
            }
            .buttonStyle(.bordered)
        }
        .onAppear {
            audio.setPreset(
                for: instanceID,
                instrument: instrument,
                program: selectedPreset.program,
                midiNote: selectedPreset.midiNote
            )
        }
    }
}
