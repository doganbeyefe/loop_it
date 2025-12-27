import Foundation
import AVFoundation

/// A single pattern lane with its own step sequence and playback speed.
struct KickTrack: Equatable {
    var pattern: [Bool]
    var speedMultiplier: Double
    var repeatCount: Int
}

final class SoundFontKickEngine: ObservableObject {

    // MARK: - Published state
    @Published var isRunning = false
    @Published var currentTrackIndices: [UUID: Set<Int>] = [:]

    // MARK: - Audio engine plumbing
    private let engine = AVAudioEngine()
    private let playbackQueue = DispatchQueue(label: "SoundFontKickEngine.playback")
    private let isRunningInPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

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

    private final class InstrumentState {
        let sampler: AVAudioUnitSampler
        var midiNote: UInt8
        var program: UInt8
        final class TrackState {
            let track: KickTrack
            var currentStepIndex: Int = 0
            var repeatRemaining: Int

            init(track: KickTrack) {
                self.track = track
                self.repeatRemaining = max(1, track.repeatCount)
            }
        }

        var trackStates: [TrackState] = []
        var timer: DispatchSourceTimer?
        var activeTrackIndex: Int = 0

        let instrument: DrumInstrument

        init(sampler: AVAudioUnitSampler, instrument: DrumInstrument, midiNote: UInt8 = 36, program: UInt8 = 0) {
            self.sampler = sampler
            self.instrument = instrument
            self.midiNote = midiNote
            self.program = program
        }
    }

    private var instrumentStates: [UUID: InstrumentState] = [:]

    // MARK: - Sequencing state
    init(soundFontName: String = "GeneralUser-GS", soundFontExtension: String = "sf2") {
        self.soundFontName = soundFontName
        self.soundFontExtension = soundFontExtension

        setupAudio()
        loadSoundFontURL()

    }

    // MARK: - Setup
    private func setupAudio() {
        guard !isRunningInPreview else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            startEngineIfNeeded()
        } catch {
            print("❌ Audio setup error:", error)
        }
    }

    private func startEngineIfNeeded() {
        guard !isRunningInPreview, !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            print("❌ Audio start error:", error)
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
    func registerInstrument(id: UUID, instrument: DrumInstrument, preset: DrumPreset) {
        playbackQueue.async {
            if let state = self.instrumentStates[id] {
                self.applyPreset(preset, to: state)
                return
            }

            let sampler = AVAudioUnitSampler()
            let state = InstrumentState(sampler: sampler, instrument: instrument)
            self.instrumentStates[id] = state
            self.engine.attach(sampler)
            self.engine.connect(sampler, to: self.engine.mainMixerNode, format: nil)
            self.startEngineIfNeeded()
            self.applyPreset(preset, to: state)
        }
    }

    func setPreset(_ preset: DrumPreset, for instrumentID: UUID) {
        playbackQueue.async {
            guard let state = self.instrumentStates[instrumentID] else { return }
            self.applyPreset(preset, to: state)
        }
    }

    func playPreview(for instrumentID: UUID) {
        playbackQueue.async {
            self.triggerNote(for: instrumentID)
        }
    }

    // MARK: - Trigger
    private func triggerNote(for instrumentID: UUID) {
        guard let state = instrumentStates[instrumentID] else { return }
        state.sampler.startNote(state.midiNote, withVelocity: velocity, onChannel: midiChannel)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            state.sampler.stopNote(state.midiNote, onChannel: self.midiChannel)
        }
    }

    // MARK: - Transport
    func start(bpm: Double, tracksByInstrument: [UUID: [KickTrack]]) {
        playbackQueue.async {
            guard !self.isRunningInternal, bpm > 0, !tracksByInstrument.isEmpty else { return }

            self.baseBpm = bpm
            self.isRunningInternal = true
            self.updateIsRunning(true)
            self.startEngineIfNeeded()

            tracksByInstrument.forEach { instrumentID, tracks in
                self.configureInstrument(instrumentID, tracks: tracks)
            }
        }
    }

    func updateSession(bpm: Double, tracksByInstrument: [UUID: [KickTrack]]) {
        playbackQueue.async {
            self.stopOnQueue()
            guard bpm > 0, !tracksByInstrument.isEmpty else { return }

            self.baseBpm = bpm
            self.isRunningInternal = true
            self.updateIsRunning(true)
            self.startEngineIfNeeded()

            tracksByInstrument.forEach { instrumentID, tracks in
                self.configureInstrument(instrumentID, tracks: tracks)
            }
        }
    }

    func updateInstrumentTracks(_ instrumentID: UUID, tracks: [KickTrack]) {
        playbackQueue.async {
            self.updateInstrumentTracksOnQueue(instrumentID, tracks: tracks)
        }
    }

    func stop() {
        playbackQueue.async {
            self.stopOnQueue()
        }
    }

    // MARK: - Timer control
    private func startInstrumentTimer(
        for instrumentID: UUID,
        startImmediately: Bool = true
    ) {
        guard let state = instrumentStates[instrumentID],
              state.trackStates.indices.contains(state.activeTrackIndex) else { return }

        let trackState = state.trackStates[state.activeTrackIndex]
        let effectiveBpm = max(1, baseBpm * trackState.track.speedMultiplier)
        let interval = 60.0 / effectiveBpm

        let timer = DispatchSource.makeTimerSource(queue: playbackQueue)
        let deadline: DispatchTime = startImmediately ? .now() : .now() + interval
        timer.schedule(deadline: deadline, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self,
                  let state = self.instrumentStates[instrumentID],
                  state.trackStates.indices.contains(state.activeTrackIndex) else { return }

            let activeTrackState = state.trackStates[state.activeTrackIndex]
            let pattern = activeTrackState.track.pattern
            let safePatternLength = max(pattern.count, 1)

            if pattern.indices.contains(activeTrackState.currentStepIndex),
               pattern[activeTrackState.currentStepIndex] {
                self.triggerNote(for: instrumentID)
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
                        self.updateCurrentTrackIndices(for: instrumentID, value: [state.activeTrackIndex])
                        self.startInstrumentTimer(for: instrumentID, startImmediately: false)
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

    private func stopInstrumentTimer(for instrumentID: UUID) {
        guard let state = instrumentStates[instrumentID] else { return }
        state.timer?.cancel()
        state.timer = nil
    }

    private func stopOnQueue() {
        isRunningInternal = false
        updateIsRunning(false)
        instrumentStates.keys.forEach { instrumentID in
            stopInstrumentTimer(for: instrumentID)
            updateCurrentTrackIndices(for: instrumentID, value: [])
        }
        instrumentStates.values.forEach { state in
            state.trackStates = []
            state.sampler.sendController(123, withValue: 0, onChannel: midiChannel)
        }
    }

    private func updateIsRunning(_ value: Bool) {
        DispatchQueue.main.async {
            self.isRunning = value
        }
    }

    private func updateCurrentTrackIndices(for instrumentID: UUID, value: Set<Int>) {
        DispatchQueue.main.async {
            self.currentTrackIndices[instrumentID] = value
        }
    }

    // MARK: - Instrument setup
    private func applyPreset(_ preset: DrumPreset, to state: InstrumentState) {
        if preset.program != state.program {
            setDrumKitProgram(for: state, program: preset.program)
        }
        state.midiNote = preset.midiNote
    }

    private func setDrumKitProgram(for state: InstrumentState, program: UInt8) {
        guard let url = sf2URL else { return }

        do {
            try state.sampler.loadSoundBankInstrument(
                at: url,
                program: program,
                bankMSB: UInt8(kAUSampler_DefaultPercussionBankMSB),
                bankLSB: 0
            )
            state.program = program
            print("✅ Drum kit loaded program:", program, "for", state.instrument.rawValue)
        } catch {
            print("❌ Failed to load drum kit program \(program) for \(state.instrument.rawValue):", error)
        }
    }

    private func configureInstrument(_ instrumentID: UUID, tracks: [KickTrack]) {
        guard let state = instrumentStates[instrumentID] else { return }
        stopInstrumentTimer(for: instrumentID)
        state.trackStates = tracks.map { InstrumentState.TrackState(track: $0) }
        state.activeTrackIndex = 0
        guard !tracks.isEmpty else {
            updateCurrentTrackIndices(for: instrumentID, value: [])
            return
        }

        updateCurrentTrackIndices(for: instrumentID, value: [state.activeTrackIndex])
        startInstrumentTimer(for: instrumentID)
    }

    private func updateInstrumentTracksOnQueue(_ instrumentID: UUID, tracks: [KickTrack]) {
        guard let state = instrumentStates[instrumentID] else { return }
        stopInstrumentTimer(for: instrumentID)
        state.trackStates = tracks.map { InstrumentState.TrackState(track: $0) }
        state.activeTrackIndex = 0
        if isRunningInternal {
            if tracks.isEmpty {
                updateCurrentTrackIndices(for: instrumentID, value: [])
            } else {
                updateCurrentTrackIndices(for: instrumentID, value: [state.activeTrackIndex])
                startInstrumentTimer(for: instrumentID)
            }
            refreshRunningState()
        }
    }

    private func refreshRunningState() {
        let hasActiveTracks = instrumentStates.values.contains { !$0.trackStates.isEmpty }
        if !hasActiveTracks {
            stopOnQueue()
        }
    }
}
