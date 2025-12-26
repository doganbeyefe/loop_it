//
//  ContentView.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import SwiftUI

struct ContentView: View {
    // MARK: - State
    @StateObject private var audio = SoundFontKickEngine()
    @State private var bpm: Double = 120
    @State private var kickPatterns: [KickPatternRow] = (0..<4).map { _ in KickPatternRow() }
    @State private var selectedPreset: KickPreset = KickPreset.all[0]

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            presetSection
            patternSection
            tempoSection
            transportSection
        }
        .padding()
        .onAppear {
            audio.setKickPreset(selectedPreset)
        }
    }
}

// MARK: - Sections
private extension ContentView {
    var headerSection: some View {
        Text("Kick")
            .font(.title2)
            .bold()
    }

    var presetSection: some View {
        VStack(spacing: 12) {
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
        }
    }

    var patternSection: some View {
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

            addPatternButton
        }
        .onChange(of: kickPatterns) { _, newPatterns in
            guard audio.isRunning else { return }
            audio.updateKickTracks(
                newPatterns.map { KickTrack(pattern: $0.steps, speedMultiplier: $0.speed) }
            )
        }
    }

    var tempoSection: some View {
        VStack {
            Text("BPM: \(Int(bpm))")
            Slider(value: $bpm, in: 40...240, step: 1)
        }
    }

    var transportSection: some View {
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

    var addPatternButton: some View {
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

    func addKickPattern() {
        kickPatterns.append(KickPatternRow())
    }
}

#Preview { ContentView() }
