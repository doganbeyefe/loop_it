//
//  ContentView.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import SwiftUI

struct ContentView: View {
    // MARK: - State
    @ObservedObject var audio: SoundFontKickEngine
    @State private var bpm: Double = 120
    @State private var instrumentInstances: [InstrumentInstance] = []
    @State private var patternsByInstance: [InstrumentInstance.ID: [KickPatternRow]] = [:]
    @State private var selectedInstanceID: InstrumentInstance.ID?
    @State private var kickPresetByInstance: [InstrumentInstance.ID: KickPreset] = [:]
    @State private var snarePresetByInstance: [InstrumentInstance.ID: SnarePreset] = [:]
    @State private var hiHatPresetByInstance: [InstrumentInstance.ID: HiHatPreset] = [:]
    private let bpmFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = 400
        return formatter
    }()

    private enum Route: Hashable {
        case editor(InstrumentInstance.ID)
    }

    var body: some View {
        NavigationStack {
            menuPage
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case let .editor(instanceID):
                        editorPage(selectedID: instanceID)
                    }
                }
        }
        .onAppear {
            initializeStateIfNeeded()
        }
        .onChange(of: instrumentInstances) { _, _ in
            ensureSelectedInstance()
            ensurePatternsForInstances()
            ensurePresetsForInstances()
        }
    }
}

// MARK: - Pages
private extension ContentView {
    var menuPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                menuHeader
                instrumentList
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    func editorPage(selectedID: InstrumentInstance.ID?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                editorHeader
//                instrumentSelection
                instrumentHeaderSection
                instrumentPatternSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .onAppear {
                if let selectedID {
                    selectedInstanceID = selectedID
                }
                ensureSelectedInstance()
                ensurePatternsForInstances()
                ensurePresetsForInstances()
            }
        }
        .navigationTitle("Pattern Editor")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Menu UI
private extension ContentView {
    var menuHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Loop It")
                .font(.title2)
                .bold()
            
            Text("Create music easily")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)

            HStack {
                Text("Instruments")
                    .font(.headline)
                Spacer()
                Menu {
                    ForEach(DrumInstrument.allCases) { instrument in
                        Button {
                            addInstrument(instrument)
                        } label: {
                            Text(instrument.title)
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel("Add instrument")
            }
        }
    }

    var instrumentList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if instrumentInstances.isEmpty {
                Text("Tap + to add instruments")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(instrumentInstances) { instance in
                    NavigationLink(value: Route.editor(instance.id)) {
                        HStack {
                            Label(instanceDisplayName(instance), systemImage: instance.instrument.systemImage)
                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
    }
}

// MARK: - Editor UI
private extension ContentView {
    var editorHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedInstance.map(instanceDisplayName) ?? "Edit your patterns")
                .font(.title2)
                .bold()
            Text("Use Update to apply your changes to playback.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    var instrumentSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instruments")
                .font(.headline)
            if instrumentInstances.isEmpty {
                Text("Add instruments from the menu page.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 12) {
                    ForEach(instrumentInstances) { instance in
                        instrumentSelectionButton(for: instance)
                    }
                }
            }
        }
    }

    var topRightSection: some View {
        HStack(spacing: 12) {
            Text("BPM")
                .font(.subheadline)
            TextField("BPM", value: $bpm, formatter: bpmFormatter)
                .frame(width: 70)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
            Button("Update") {
                applyUpdate()
            }
            .buttonStyle(.borderedProminent)

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
                addPatternForSelectedInstance()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add pattern")
            Spacer()
        }
    }
}

// MARK: - Sections
private extension ContentView {
    var instrumentHeaderSection: some View {
        guard let selectedInstance else {
            return AnyView(EmptyView())
        }

        switch selectedInstance.instrument {
        case .kick:
            return AnyView(
                headerSection(
                    title: instanceTitle(for: .kick),
                    selectedPreset: kickPresetBinding(for: selectedInstance),
                    presets: KickPreset.all,
                    onPreview: {
                        let preset = kickPreset(for: selectedInstance)
                        audio.setPreset(
                            for: selectedInstance.id,
                            instrument: .kick,
                            program: preset.program,
                            midiNote: preset.midiNote
                        )
                        audio.playPreview(for: selectedInstance.id)
                    }
                )
            )
        case .snare:
            return AnyView(
                headerSection(
                    title: instanceTitle(for: .snare),
                    selectedPreset: snarePresetBinding(for: selectedInstance),
                    presets: SnarePreset.all,
                    onPreview: {
                        let preset = snarePreset(for: selectedInstance)
                        audio.setPreset(
                            for: selectedInstance.id,
                            instrument: .snare,
                            program: preset.program,
                            midiNote: preset.midiNote
                        )
                        audio.playPreview(for: selectedInstance.id)
                    }
                )
            )
        case .hiHat:
            return AnyView(
                headerSection(
                    title: instanceTitle(for: .hiHat),
                    selectedPreset: hiHatPresetBinding(for: selectedInstance),
                    presets: HiHatPreset.all,
                    onPreview: {
                        let preset = hiHatPreset(for: selectedInstance)
                        audio.setPreset(
                            for: selectedInstance.id,
                            instrument: .hiHat,
                            program: preset.program,
                            midiNote: preset.midiNote
                        )
                        audio.playPreview(for: selectedInstance.id)
                    }
                )
            )
        }
    }

    var instrumentPatternSection: some View {
        guard let selectedInstance else {
            return AnyView(EmptyView())
        }
        let patternsBinding = bindingForPatterns(instanceID: selectedInstance.id)
        return AnyView(
            patternSection(
                for: patternsBinding,
                instanceID: selectedInstance.id,
                onDelete: removePattern
            )
        )
    }

    func instrumentSelectionButton(for instance: InstrumentInstance) -> some View {
        let isSelected = selectedInstanceID == instance.id
        return Button {
            selectedInstanceID = instance.id
        } label: {
            Label(instanceDisplayName(instance), systemImage: instance.instrument.systemImage)
                .frame(maxWidth: .infinity)
        }
//        .buttonStyle(isSelected ? .borderedProminent : .bordered)
    }

    func headerSection<Preset: DrumPreset>(
        title: String,
        selectedPreset: Binding<Preset>,
        presets: [Preset],
        onPreview: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Picker(title, selection: selectedPreset) {
                ForEach(presets) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.menu)

            Button("Preview \(title)") {
                onPreview()
            }
            .buttonStyle(.bordered)
            topRightSection
        }
    }

    func patternSection(
        for patterns: Binding<[KickPatternRow]>,
        instanceID: InstrumentInstance.ID,
        onDelete: @escaping (KickPatternRow.ID) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(patterns) { $pattern in
                let localIndex = patterns.wrappedValue.firstIndex(where: { $0.id == pattern.id }) ?? 0
                let isActive = audio.currentTrackIndices[instanceID]?.contains(localIndex) == true
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
    }
}

// MARK: - State helpers
private extension ContentView {
    var selectedInstance: InstrumentInstance? {
        instrumentInstances.first { $0.id == selectedInstanceID }
    }

    func initializeStateIfNeeded() {
        ensurePatternsForInstances()
        ensureSelectedInstance()
        ensurePresetsForInstances()
    }

    func ensureSelectedInstance() {
        if selectedInstanceID == nil || !instrumentInstances.contains(where: { $0.id == selectedInstanceID }) {
            selectedInstanceID = instrumentInstances.first?.id
        }
    }

    func ensurePatternsForInstances() {
        instrumentInstances.forEach { instance in
            if patternsByInstance[instance.id] == nil {
                patternsByInstance[instance.id] = [KickPatternRow()]
            }
        }
    }

    func ensurePresetsForInstances() {
        instrumentInstances.forEach { instance in
            switch instance.instrument {
            case .kick:
                if kickPresetByInstance[instance.id] == nil {
                    kickPresetByInstance[instance.id] = KickPreset.all[0]
                }
            case .snare:
                if snarePresetByInstance[instance.id] == nil {
                    snarePresetByInstance[instance.id] = SnarePreset.all[0]
                }
            case .hiHat:
                if hiHatPresetByInstance[instance.id] == nil {
                    hiHatPresetByInstance[instance.id] = HiHatPreset.all[0]
                }
            }
        }
    }

    func bindingForPatterns(instanceID: InstrumentInstance.ID) -> Binding<[KickPatternRow]> {
        Binding(
            get: { patternsByInstance[instanceID] ?? [KickPatternRow()] },
            set: { patternsByInstance[instanceID] = $0 }
        )
    }

    func kickPreset(for instance: InstrumentInstance) -> KickPreset {
        kickPresetByInstance[instance.id] ?? KickPreset.all[0]
    }

    func snarePreset(for instance: InstrumentInstance) -> SnarePreset {
        snarePresetByInstance[instance.id] ?? SnarePreset.all[0]
    }

    func hiHatPreset(for instance: InstrumentInstance) -> HiHatPreset {
        hiHatPresetByInstance[instance.id] ?? HiHatPreset.all[0]
    }

    func kickPresetBinding(for instance: InstrumentInstance) -> Binding<KickPreset> {
        Binding(
            get: { kickPreset(for: instance) },
            set: { kickPresetByInstance[instance.id] = $0 }
        )
    }

    func snarePresetBinding(for instance: InstrumentInstance) -> Binding<SnarePreset> {
        Binding(
            get: { snarePreset(for: instance) },
            set: { snarePresetByInstance[instance.id] = $0 }
        )
    }

    func hiHatPresetBinding(for instance: InstrumentInstance) -> Binding<HiHatPreset> {
        Binding(
            get: { hiHatPreset(for: instance) },
            set: { hiHatPresetByInstance[instance.id] = $0 }
        )
    }

    func instanceDisplayName(_ instance: InstrumentInstance) -> String {
        let index = indexForInstance(instance)
        return "\(instance.instrument.title) \(index)"
    }

    func indexForInstance(_ instance: InstrumentInstance) -> Int {
        let matches = instrumentInstances.filter { $0.instrument == instance.instrument }
        let index = matches.firstIndex { $0.id == instance.id } ?? 0
        return index + 1
    }

    func instanceTitle(for instrument: DrumInstrument) -> String {
        guard let selectedInstance else {
            return instrument.title
        }
        return "\(instrument.title) \(indexForInstance(selectedInstance))"
    }
}

// MARK: - Actions
private extension ContentView {
    func addPatternForSelectedInstance() {
        guard let selectedInstance else { return }
        withAnimation(.easeInOut) {
            var patterns = patternsByInstance[selectedInstance.id] ?? []
            patterns.append(KickPatternRow())
            patternsByInstance[selectedInstance.id] = patterns
        }
    }

    func removePattern(at id: KickPatternRow.ID) {
        guard let selectedInstance else { return }
        guard var patterns = patternsByInstance[selectedInstance.id] else { return }
        guard let index = patterns.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut) {
            patterns.remove(at: index)
            patternsByInstance[selectedInstance.id] = patterns
        }
    }

    func applyUpdate() {
        audio.updateSessionOnNextBar(bpm: bpm, tracksByInstance: tracksByInstance())
    }

    func tracksByInstance() -> [InstrumentInstance.ID: InstrumentPlaybackConfig] {
        var mapping: [InstrumentInstance.ID: InstrumentPlaybackConfig] = [:]
        for instance in instrumentInstances {
            let patterns = patternsByInstance[instance.id] ?? []
            let tracks = tracks(for: patterns)
            switch instance.instrument {
            case .kick:
                let preset = kickPreset(for: instance)
                mapping[instance.id] = InstrumentPlaybackConfig(
                    instrument: instance.instrument,
                    tracks: tracks,
                    program: preset.program,
                    midiNote: preset.midiNote
                )
            case .snare:
                let preset = snarePreset(for: instance)
                mapping[instance.id] = InstrumentPlaybackConfig(
                    instrument: instance.instrument,
                    tracks: tracks,
                    program: preset.program,
                    midiNote: preset.midiNote
                )
            case .hiHat:
                let preset = hiHatPreset(for: instance)
                mapping[instance.id] = InstrumentPlaybackConfig(
                    instrument: instance.instrument,
                    tracks: tracks,
                    program: preset.program,
                    midiNote: preset.midiNote
                )
            }
        }
        return mapping
    }

    func addInstrument(_ instrument: DrumInstrument) {
        let newInstance = InstrumentInstance(instrument: instrument)
        instrumentInstances.append(newInstance)
        patternsByInstance[newInstance.id] = [KickPatternRow()]
        selectedInstanceID = newInstance.id
        switch instrument {
        case .kick:
            kickPresetByInstance[newInstance.id] = KickPreset.all[0]
        case .snare:
            snarePresetByInstance[newInstance.id] = SnarePreset.all[0]
        case .hiHat:
            hiHatPresetByInstance[newInstance.id] = HiHatPreset.all[0]
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

#Preview { ContentView(audio: SoundFontKickEngine()) }

//
