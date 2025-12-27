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
    @State private var snarePatterns: [KickPatternRow] = (0..<1).map { _ in KickPatternRow() }
    @State private var hiHatPatterns: [KickPatternRow] = (0..<1).map { _ in KickPatternRow() }
    @State private var selectedKickPreset: KickPreset = KickPreset.all[0]
    @State private var selectedSnarePreset: SnarePreset = SnarePreset.all[0]
    @State private var selectedHiHatPreset: HiHatPreset = HiHatPreset.all[0]
    @State private var selectedInstrument: DrumInstrument = .kick
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
                instrumentMenu
                headerSection
                patternSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .onAppear {
                applySelectedPreset()
            }
            .onChange(of: selectedInstrument) { _, _ in
                applySelectedPreset()
            }
        }
    }
}

// MARK: - Sections
private extension ContentView {
    var instrumentMenu: some View {
        Picker("Instrument", selection: $selectedInstrument) {
            ForEach(DrumInstrument.allCases) { instrument in
                Label(instrument.title, systemImage: instrument.systemImage)
                    .tag(instrument)
            }
        }
        .pickerStyle(.segmented)
    }

    var headerSection: some View {
        instrumentHeaderSection
    }

    var patternSection: some View {
        instrumentPatternSection
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
                    applySelectedPreset()
                    audio.start(bpm: bpm, tracks: tracks(for: selectedPatterns))
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
                addPatternForSelectedInstrument()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add pattern")
            Spacer()
        }
    }

    var instrumentHeaderSection: some View {
        switch selectedInstrument {
        case .kick:
            return AnyView(
                headerSection(
                    title: "Kick",
                    selectedPreset: $selectedKickPreset,
                    presets: KickPreset.all,
                    onPresetChange: { audio.setKickPreset($0) },
                    onPreview: {
                        audio.setKickPreset(selectedKickPreset)
                        audio.playPreview()
                    }
                )
            )
        case .snare:
            return AnyView(
                headerSection(
                    title: "Snare",
                    selectedPreset: $selectedSnarePreset,
                    presets: SnarePreset.all,
                    onPresetChange: { audio.setSnarePreset($0) },
                    onPreview: {
                        audio.setSnarePreset(selectedSnarePreset)
                        audio.playPreview()
                    }
                )
            )
        case .hiHat:
            return AnyView(
                headerSection(
                    title: "Hi-Hat",
                    selectedPreset: $selectedHiHatPreset,
                    presets: HiHatPreset.all,
                    onPresetChange: { audio.setHiHatPreset($0) },
                    onPreview: {
                        audio.setHiHatPreset(selectedHiHatPreset)
                        audio.playPreview()
                    }
                )
            )
        }
    }

    var instrumentPatternSection: some View {
        switch selectedInstrument {
        case .kick:
            return AnyView(patternSection(for: $kickPatterns, onDelete: removeKickPattern))
        case .snare:
            return AnyView(patternSection(for: $snarePatterns, onDelete: removeSnarePattern))
        case .hiHat:
            return AnyView(patternSection(for: $hiHatPatterns, onDelete: removeHiHatPattern))
        }
    }

    func headerSection<Preset: DrumPreset>(
        title: String,
        selectedPreset: Binding<Preset>,
        presets: [Preset],
        onPresetChange: @escaping (Preset) -> Void,
        onPreview: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title)
                .font(.title2)
                .bold()
            Picker(title, selection: selectedPreset) {
                ForEach(presets) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedPreset.wrappedValue) { _, newPreset in
                onPresetChange(newPreset)
            }

            Button("Preview \(title)") {
                onPreview()
            }
            .buttonStyle(.bordered)
//            Spacer()
            topRightSection
        }
    }

    func patternSection(
        for patterns: Binding<[KickPatternRow]>,
        onDelete: @escaping (KickPatternRow.ID) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach($patterns) { $pattern in
                let isActive = audio.currentTrackIndex == patterns.wrappedValue.firstIndex(where: { $0.id == pattern.id })
                HStack(spacing: 16) {
                    KickPatternView(steps: $pattern.steps)
                    Spacer()
                    KickSpeedControl(
                        speed: $pattern.speed,
                        repeatCount: $pattern.repeatCount,
                        onDelete: {
                            onDelete(pattern.id)
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
        .animation(.easeInOut, value: patterns.wrappedValue)
        .onChange(of: patterns.wrappedValue) { _, newPatterns in
            guard audio.isRunning else { return }
            audio.updateKickTracks(newPatterns.map {
                KickTrack(pattern: $0.steps, speedMultiplier: $0.speed, repeatCount: $0.repeatCount)
            })
        }
    }

    func addPatternForSelectedInstrument() {
        withAnimation(.easeInOut) {
            switch selectedInstrument {
            case .kick:
                kickPatterns.append(KickPatternRow())
            case .snare:
                snarePatterns.append(KickPatternRow())
            case .hiHat:
                hiHatPatterns.append(KickPatternRow())
            }
        }
    }

    func removeKickPattern(at id: KickPatternRow.ID) {
        guard let index = kickPatterns.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut) {
            kickPatterns.remove(at: index)
        }
    }

    func removeSnarePattern(at id: KickPatternRow.ID) {
        guard let index = snarePatterns.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut) {
            snarePatterns.remove(at: index)
        }
    }

    func removeHiHatPattern(at id: KickPatternRow.ID) {
        guard let index = hiHatPatterns.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut) {
            hiHatPatterns.remove(at: index)
        }
    }

    var selectedPatterns: [KickPatternRow] {
        switch selectedInstrument {
        case .kick:
            return kickPatterns
        case .snare:
            return snarePatterns
        case .hiHat:
            return hiHatPatterns
        }
    }

    func applySelectedPreset() {
        switch selectedInstrument {
        case .kick:
            audio.setKickPreset(selectedKickPreset)
        case .snare:
            audio.setSnarePreset(selectedSnarePreset)
        case .hiHat:
            audio.setHiHatPreset(selectedHiHatPreset)
        }
    }

    func tracks(for patterns: [KickPatternRow]) -> [KickTrack] {
        patterns.map {
            KickTrack(
                pattern: $0.steps,
                speedMultiplier: $0.speed,
                repeatCount: $0.repeatCount
            )
        }
    }
}

#Preview { ContentView() }
