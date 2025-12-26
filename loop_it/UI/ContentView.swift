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
    @State private var kickPatterns: [KickPatternRow] = (0..<4).map { _ in
        KickPatternRow()
    }

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

            // Pattern UI
            VStack(alignment: .leading, spacing: 16) {
                ForEach(kickPatterns.indices, id: \.self) { index in
                    let isActive = audio.currentTrackIndex == index
                    HStack(spacing: 16) {
                        KickPatternView(steps: $kickPatterns[index].steps)

                        Spacer()

                        KickSpeedControl(speed: $kickPatterns[index].speed)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                }

                HStack {
                    Spacer()
                    Button {
                        addKickPattern()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add kick pattern")
                    Spacer()
                }
            }
            .onChange(of: kickPatterns) { _, newPatterns in
                if audio.isRunning {
                    audio.updateKickTracks(
                        newPatterns.map { KickTrack(pattern: $0.steps, speedMultiplier: $0.speed) }
                    )
                }
            }

            VStack {
                Text("BPM: \(Int(bpm))")
                Slider(value: $bpm, in: 40...240, step: 1)
            }

            HStack {
                Button("Start") {
                    audio.setKickPreset(selectedPreset)
                    audio.start(
                        bpm: bpm,
                        tracks: kickPatterns.map {
                            KickTrack(pattern: $0.steps, speedMultiplier: $0.speed)
                        }
                    )
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
        }
    }
}

private extension Double {
    var cleanSpeedText: String {
        // show 1 instead of 1.0
        if self == floor(self) { return String(Int(self)) }
        return String(self)
    }
}

private struct KickPatternRow: Identifiable, Equatable {
    let id = UUID()
    var steps: [Bool] = [true, false, false, false]
    var speed: Double = 1.0
}

private struct KickSpeedControl: View {
    @Binding var speed: Double

    var body: some View {
        HStack(spacing: 10) {
            Button("/2") {
                speed = max(speed / 2.0, 0.25)
            }
            .buttonStyle(.bordered)

            Text("speed: \(speed.cleanSpeedText)")
                .font(.subheadline)
                .monospacedDigit()

            Button("x2") {
                speed = min(speed * 2.0, 8.0)
            }
            .buttonStyle(.bordered)
        }
    }
}

private extension ContentView {
    func addKickPattern() {
        kickPatterns.append(KickPatternRow())
    }
}


#Preview { ContentView() }
