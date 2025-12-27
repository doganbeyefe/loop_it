//
//  KickSettingsView.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import SwiftUI

struct KickSettingsView: View {
    @ObservedObject var audio: SoundFontKickEngine
    let instanceID: InstrumentInstance.ID
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
                audio.setPreset(newPreset, for: instanceID)
            }

            Button("Preview Kick") {
                audio.setPreset(selectedPreset, for: instanceID)
                audio.playPreview(for: instanceID)
            }
            .buttonStyle(.bordered)
        }
        .onAppear {
            audio.registerInstrument(id: instanceID, instrument: .kick, preset: selectedPreset)
            audio.setPreset(selectedPreset, for: instanceID)
        }
    }
}
