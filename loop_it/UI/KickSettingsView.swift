//
//  KickSettingsView.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import SwiftUI

struct KickSettingsView: View {
    @ObservedObject var audio: SoundFontKickEngine
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
                audio.setKickPreset(newPreset)
            }

            Button("Preview Kick") {
                audio.setKickPreset(selectedPreset)
                audio.playPreview(for: .kick)
            }
            .buttonStyle(.bordered)
        }
        .onAppear {
            audio.setKickPreset(selectedPreset)
        }
    }
}
