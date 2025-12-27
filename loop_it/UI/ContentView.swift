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
    @State private var kickPatterns: [KickPatternRow] = (0..<1).map { _ in KickPatternRow() }
    @State private var selectedPreset: KickPreset = KickPreset.all[0]
    private let bpmFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = 400
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                patternSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .onAppear {
                audio.setKickPreset(selectedPreset)
            }
        }
    }
}

// MARK: - Sections
private extension ContentView {
    var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("Kick")
                .font(.title2)
                .bold()
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
            Spacer()
            topRightSection
        }
    }

    var patternSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach($kickPatterns) { $pattern in
                let isActive = audio.currentTrackIndex == kickPatterns.firstIndex(where: { $0.id == pattern.id })
                HStack(spacing: 16) {
                    KickPatternView(steps: $pattern.steps)
                    Spacer()
                    KickSpeedControl(
                        speed: $pattern.speed,
                        repeatCount: $pattern.repeatCount,
                        onDelete: {
                            removeKickPattern(at: pattern.id)
                        }
                    )
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
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            addPatternButton
        }
        .animation(.easeInOut, value: kickPatterns)
        .onChange(of: kickPatterns) { _, newPatterns in
            guard audio.isRunning else { return }
            audio.updateKickTracks(newPatterns.map {
                KickTrack(pattern: $0.steps, speedMultiplier: $0.speed, repeatCount: $0.repeatCount)
            })
        }
    }

    var topRightSection: some View {
            HStack {
                Text("BPM")
                    .font(.subheadline)
                TextField("BPM", value: $bpm, formatter: bpmFormatter)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                Button("Start") {
                    audio.setKickPreset(selectedPreset)
                    audio.start(
                        bpm: bpm,
                        tracks: kickPatterns.map {
                            KickTrack(
                                pattern: $0.steps,
                                speedMultiplier: $0.speed,
                                repeatCount: $0.repeatCount
                            )
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
        withAnimation(.easeInOut) {
            kickPatterns.append(KickPatternRow())
        }
    }

    func removeKickPattern(at id: KickPatternRow.ID) {
        guard let index = kickPatterns.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut) {
            kickPatterns.remove(at: index)
        }
    }
}

#Preview { ContentView() }
