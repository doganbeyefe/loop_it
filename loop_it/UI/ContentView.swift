//
//  ContentView.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audio = SoundFontKickEngine()
    @State private var bpm: Double = 120

    // 4 steps = 1 bar in 4/4 (1 step per beat)
    @State private var pattern: [Bool] = [true, false, false, false]

    // if you already have the one-picker:
    @State private var selectedPreset: KickPreset = KickPreset.all[0]

    var body: some View {
        VStack(spacing: 24) {
            Text("Kick")
                .font(.title2).bold()

            // One picker for kick sound
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
                audio.playKickPreview()
            }
            .buttonStyle(.bordered)

            // ✅ Pattern UI
            KickPatternView(steps: $pattern)

            VStack {
                Text("BPM: \(Int(bpm))")
                Slider(value: $bpm, in: 40...240, step: 1)
            }

            HStack {
                Button("Start") {
                    audio.setKickPreset(selectedPreset)
                    audio.kickPattern = pattern   // ✅ pass pattern into engine
                    audio.start(bpm: bpm)
                }
                .buttonStyle(.borderedProminent)
                .disabled(audio.isRunning)

                Button("Stop") {
                    audio.stop()
                }
                .buttonStyle(.bordered)
                .disabled(!audio.isRunning)
            }
        }
        .padding()
        .onAppear {
            audio.setKickPreset(selectedPreset)
            audio.kickPattern = pattern
        }
    }
}

#Preview { ContentView() }
