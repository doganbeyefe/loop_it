import Foundation
import AVFoundation

/// A single pattern lane with its own step sequence and playback speed.
struct DrumTrack: Equatable {
    var pattern: [Bool]
    var speedMultiplier: Double
    var repeatCount: Int
}

/// Unique identifier for a user-added instrument instance.
typealias InstrumentInstanceID = InstrumentKey

/// Payload describing what an instrument instance should play and how it should sound.
struct InstrumentPlaybackConfig {
    let instrument: DrumInstrument
    let tracks: [DrumTrack]
    let program: UInt8
    let midiNote: UInt8
}

final class SoundFontDrumEngine: ObservableObject {

    // MARK: - Published state
    @Published var isRunning = false
    @Published var currentTrackIndices: [InstrumentInstanceID: Set<Int>] = [:]

    // MARK: - Audio engine plumbing
    private let engine = AVAudioEngine()
    private let playbackQueue = DispatchQueue(label: "SoundFontDrumEngine.playback")

    // MARK: - Playback configuration
    private var baseBpm: Double = 120
    private var isRunningInternal = false

    // MARK: - SoundFont configuration
    private let soundFontName: String
    private let soundFontExtension: String

    /// General MIDI drum channel (MIDI ch.10 => index 9).
    var midiChannel: UInt8 = 9

    var velocity: UInt8 = 110

    /// Keep the SF2 URL so we can reload different programs.
    private var sf2URL: URL?

    private final class SamplerState {
        let sampler: AVAudioUnitSampler
        var midiNote: UInt8
        var program: UInt8
        var hasLoadedBank: Bool

        init(sampler: AVAudioUnitSampler, midiNote: UInt8 = 36, program: UInt8 = 255) {
            self.sampler = sampler
            self.midiNote = midiNote
            self.program = program
            self.hasLoadedBank = false
        }
    }

    private final class InstanceState {
        final class TrackState {
            let track: DrumTrack
            var currentStepIndex: Int = 0
            var repeatRemaining: Int

            init(track: DrumTrack) {
                self.track = track
                self.repeatRemaining = max(1, track.repeatCount)
            }
        }

        let instrument: DrumInstrument
        var trackStates: [TrackState] = []
        var timer: DispatchSourceTimer?
        var activeTrackIndex: Int = 0

        init(instrument: DrumInstrument) {
            self.instrument = instrument
        }
    }

    private var samplerStates: [InstrumentInstanceID: SamplerState] = [:]
    private var instanceStates: [InstrumentInstanceID: InstanceState] = [:]

    // MARK: - Sequencing state
    init(soundFontName: String = "GeneralUser-GS", soundFontExtension: String = "sf2") {
        self.soundFontName = soundFontName
        self.soundFontExtension = soundFontExtension

        setupAudio()
        loadSoundFontURL()
    }

    // MARK: - Setup
    private func setupAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            let outputFormat = engine.outputNode.inputFormat(forBus: 0)
            engine.connect(engine.mainMixerNode, to: engine.outputNode, format: outputFormat)
        } catch {
            print("❌ Audio setup error:", error)
        }
    }

    private func loadSoundFontURL() {
        guard let url = Bundle.main.url(forResource: soundFontName, withExtension: soundFontExtension) else {
            print("❌ SoundFont not found: \(soundFontName).\(soundFontExtension)")
            return
        }
        self.sf2URL = url
        print("✅ SF2 URL ready:", url.lastPathComponent)
    }

    // MARK: - Drum kit loading
    func setPreset(
        for instanceID: InstrumentInstanceID,
        instrument: DrumInstrument,
        program: UInt8,
        midiNote: UInt8
    ) {
        playbackQueue.async {
            _ = self.ensureSampler(for: instanceID, instrument: instrument, program: program, midiNote: midiNote)
        }
    }

    func playPreview(for instanceID: InstrumentInstanceID) {
        playbackQueue.async {
            self.triggerNote(for: instanceID)
        }
    }

    // MARK: - Trigger
    private func triggerNote(for instanceID: InstrumentInstanceID) {
        guard let samplerState = samplerStates[instanceID] else { return }
        samplerState.sampler.startNote(samplerState.midiNote, withVelocity: velocity, onChannel: midiChannel)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            samplerState.sampler.stopNote(samplerState.midiNote, onChannel: self.midiChannel)
        }
    }

    // MARK: - Transport
    func start(bpm: Double, tracksByInstance: [InstrumentInstanceID: InstrumentPlaybackConfig]) {
        playbackQueue.async {
            let hasTracks = tracksByInstance.values.contains { !$0.tracks.isEmpty }
            guard !self.isRunningInternal, bpm > 0, hasTracks else { return }

            self.preloadSamplers(with: tracksByInstance)

            self.baseBpm = bpm
            self.isRunningInternal = true
            self.updateIsRunning(true)

            let startTime = DispatchTime.now() + 0.02
            self.configureInstances(with: tracksByInstance, startTime: startTime)
            self.refreshRunningState()
        }
    }

    func updateSession(bpm: Double, tracksByInstance: [InstrumentInstanceID: InstrumentPlaybackConfig]) {
        playbackQueue.async {
            self.stopOnQueue()
            let hasTracks = tracksByInstance.values.contains { !$0.tracks.isEmpty }
            guard bpm > 0, hasTracks else { return }

            self.baseBpm = bpm
            self.isRunningInternal = true
            self.updateIsRunning(true)

            let startTime = DispatchTime.now() + 0.05
            self.configureInstances(with: tracksByInstance, startTime: startTime)
            self.refreshRunningState()
        }
    }

    /// Applies a new session aligned to the next bar boundary (default 4 beats).
    func updateSessionOnNextBar(
        bpm: Double,
        tracksByInstance: [InstrumentInstanceID: InstrumentPlaybackConfig],
        beatsPerBar: Int = 4
    ) {
        playbackQueue.async {
            let hasTracks = tracksByInstance.values.contains { !$0.tracks.isEmpty }
            guard bpm > 0, hasTracks else { return }

            let barDuration = Double(beatsPerBar) * (60.0 / bpm)
            let startTime = DispatchTime.now() + barDuration

            self.preloadSamplers(with: tracksByInstance)

            self.playbackQueue.asyncAfter(deadline: startTime) {
                self.baseBpm = bpm
                self.isRunningInternal = true
                self.updateIsRunning(true)
                self.configureInstances(with: tracksByInstance, startTime: startTime)
                self.refreshRunningState()
            }
        }
    }

    func stop() {
        playbackQueue.async {
            self.stopOnQueue()
        }
    }

    // MARK: - Timer control
    private func startInstrumentTimer(
        for instanceID: InstrumentInstanceID,
        startImmediately: Bool = true,
        startTime: DispatchTime? = nil
    ) {
        guard let state = instanceStates[instanceID],
              let samplerState = samplerStates[instanceID],
              state.trackStates.indices.contains(state.activeTrackIndex) else { return }

        let trackState = state.trackStates[state.activeTrackIndex]
        let effectiveBpm = max(1, baseBpm * trackState.track.speedMultiplier)
        let interval = 60.0 / effectiveBpm

        let timer = DispatchSource.makeTimerSource(queue: playbackQueue)
        let deadline: DispatchTime
        if let startTime {
            deadline = startTime
        } else {
            deadline = startImmediately ? .now() : .now() + interval
        }
        timer.schedule(deadline: deadline, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self,
                  let state = self.instanceStates[instanceID],
                  let samplerState = self.samplerStates[instanceID],
                  state.trackStates.indices.contains(state.activeTrackIndex) else { return }

            let activeTrackState = state.trackStates[state.activeTrackIndex]
            let pattern = activeTrackState.track.pattern
            let safePatternLength = max(pattern.count, 1)

            if pattern.indices.contains(activeTrackState.currentStepIndex),
               pattern[activeTrackState.currentStepIndex] {
                samplerState.sampler.startNote(samplerState.midiNote, withVelocity: self.velocity, onChannel: self.midiChannel)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak samplerState, weak self] in
                    guard let samplerState, let self else { return }
                    samplerState.sampler.stopNote(samplerState.midiNote, onChannel: self.midiChannel)
                }
            }

            let nextStep = activeTrackState.currentStepIndex + 1
            if nextStep >= safePatternLength {
                activeTrackState.currentStepIndex = 0
                if activeTrackState.repeatRemaining > 1 {
                    activeTrackState.repeatRemaining -= 1
                } else {
                    activeTrackState.repeatRemaining = max(1, activeTrackState.track.repeatCount)
                    if !state.trackStates.isEmpty {
                        state.activeTrackIndex = (state.activeTrackIndex + 1) % state.trackStates.count
                        self.updateCurrentTrackIndices(for: instanceID, value: [state.activeTrackIndex])
                        self.startInstrumentTimer(for: instanceID, startImmediately: false)
                        return
                    }
                }
            } else {
                activeTrackState.currentStepIndex = nextStep
            }
        }

        state.timer?.cancel()
        state.timer = timer
        timer.resume()
    }

    private func stopInstrumentTimer(for instanceID: InstrumentInstanceID) {
        guard let state = instanceStates[instanceID] else { return }
        state.timer?.cancel()
        state.timer = nil
    }

    private func stopOnQueue() {
        isRunningInternal = false
        updateIsRunning(false)

        instanceStates.keys.forEach { instanceID in
            stopInstrumentTimer(for: instanceID)
            updateCurrentTrackIndices(for: instanceID, value: [])
        }
        instanceStates = [:]

        samplerStates.values.forEach { samplerState in
            samplerState.sampler.sendController(123, withValue: 0, onChannel: midiChannel)
            engine.disconnectNodeInput(samplerState.sampler)
            engine.disconnectNodeOutput(samplerState.sampler)
            engine.detach(samplerState.sampler)
        }
        samplerStates = [:]
    }

    private func updateIsRunning(_ value: Bool) {
        DispatchQueue.main.async {
            self.isRunning = value
        }
    }

    private func updateCurrentTrackIndices(for instanceID: InstrumentInstanceID, value: Set<Int>) {
        DispatchQueue.main.async {
            self.currentTrackIndices[instanceID] = value
        }
    }

    // MARK: - Instrument setup
    private func ensureSampler(
        for instanceID: InstrumentInstanceID,
        instrument: DrumInstrument,
        program: UInt8,
        midiNote: UInt8
    ) -> SamplerState? {
        guard let url = sf2URL else { return nil }

        let samplerState: SamplerState
        if let existing = samplerStates[instanceID] {
            samplerState = existing
        } else {
            let sampler = AVAudioUnitSampler()
            samplerState = SamplerState(sampler: sampler)
            samplerStates[instanceID] = samplerState
            engine.attach(sampler)
            engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        }

        startEngineIfNeeded()

        let needsProgramLoad = !samplerState.hasLoadedBank || samplerState.program != program
        if needsProgramLoad {
            do {
                try samplerState.sampler.loadSoundBankInstrument(
                    at: url,
                    program: program,
                    bankMSB: UInt8(kAUSampler_DefaultPercussionBankMSB),
                    bankLSB: 0
                )
            samplerState.program = program
            samplerState.hasLoadedBank = true
            print("✅ Drum kit loaded program:", program, "for", instrument.rawValue, "instance:", instanceID.id)
        } catch {
            print("❌ Failed to load drum kit program \(program) for \(instrument.rawValue) instance \(instanceID.id):", error)
        }
    }

        samplerState.midiNote = midiNote

        if let state = instanceStates[instanceID] {
            if state.instrument != instrument {
                instanceStates[instanceID] = InstanceState(instrument: instrument)
            }
        } else {
            instanceStates[instanceID] = InstanceState(instrument: instrument)
        }

        return samplerState
    }

    private func preloadSamplers(with tracksByInstance: [InstrumentInstanceID: InstrumentPlaybackConfig]) {
        tracksByInstance.forEach { instanceID, payload in
            _ = ensureSampler(
                for: instanceID,
                instrument: payload.instrument,
                program: payload.program,
                midiNote: payload.midiNote
            )
        }
    }

    private func configureInstances(
        with tracksByInstance: [InstrumentInstanceID: InstrumentPlaybackConfig],
        startTime: DispatchTime?
    ) {
        let requestedIDs = Set(tracksByInstance.keys)
        let existingIDs = Set(instanceStates.keys)

        // Remove instances that are no longer present.
        let removed = existingIDs.subtracting(requestedIDs)
        removed.forEach { id in
            stopInstrumentTimer(for: id)
            instanceStates[id] = nil
            updateCurrentTrackIndices(for: id, value: [])
            if let samplerState = samplerStates[id] {
                samplerState.sampler.sendController(123, withValue: 0, onChannel: midiChannel)
                engine.disconnectNodeInput(samplerState.sampler)
                engine.disconnectNodeOutput(samplerState.sampler)
                engine.detach(samplerState.sampler)
                samplerStates[id] = nil
            }
        }

        // Update or create the requested instances.
        tracksByInstance.forEach { instanceID, payload in
            configureInstance(
                id: instanceID,
                instrument: payload.instrument,
                tracks: payload.tracks,
                program: payload.program,
                midiNote: payload.midiNote,
                startTime: startTime
            )
        }
    }

    private func configureInstance(
        id: InstrumentInstanceID,
        instrument: DrumInstrument,
        tracks: [DrumTrack],
        program: UInt8,
        midiNote: UInt8,
        startTime: DispatchTime?
    ) {
        guard ensureSampler(for: id, instrument: instrument, program: program, midiNote: midiNote) != nil else { return }

        let state = instanceStates[id] ?? InstanceState(instrument: instrument)
        stopInstrumentTimer(for: id)
        state.trackStates = tracks.map { InstanceState.TrackState(track: $0) }
        state.activeTrackIndex = 0
        instanceStates[id] = state

        guard !tracks.isEmpty else {
            updateCurrentTrackIndices(for: id, value: [])
            return
        }

        updateCurrentTrackIndices(for: id, value: [state.activeTrackIndex])
        startInstrumentTimer(for: id, startImmediately: startTime == nil, startTime: startTime)
    }

    private func refreshRunningState() {
        let hasActiveTracks = instanceStates.values.contains { !$0.trackStates.isEmpty }
        if !hasActiveTracks {
            stopOnQueue()
        }
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            print("❌ Failed to start audio engine:", error)
        }
    }
}
