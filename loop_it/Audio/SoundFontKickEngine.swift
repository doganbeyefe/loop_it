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
    @Published var currentTrackIndices: [DrumInstrument: Int?] = [:]

    // MARK: - Audio engine plumbing
    private let engine = AVAudioEngine()
    private let playbackQueue = DispatchQueue(label: "SoundFontKickEngine.playback")

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
        var tracks: [KickTrack] = []
        var timer: DispatchSourceTimer?
        var currentTrackIndex: Int = 0
        var currentStepIndex: Int = 0
        var currentTrackRepeatRemaining: Int = 1

        init(sampler: AVAudioUnitSampler, midiNote: UInt8 = 36, program: UInt8 = 0) {
            self.sampler = sampler
            self.midiNote = midiNote
            self.program = program
        }
    }

    private var instrumentStates: [DrumInstrument: InstrumentState] = [:]

    // MARK: - Sequencing state
    init(soundFontName: String = "GeneralUser-GS", soundFontExtension: String = "sf2") {
        self.soundFontName = soundFontName
        self.soundFontExtension = soundFontExtension

        setupAudio()
        loadSoundFontURL()

        // Default kit: Standard 1.
        DrumInstrument.allCases.forEach { instrument in
            setDrumKitProgram(for: instrument, program: 0)
        }
    }

    // MARK: - Setup
    private func setupAudio() {
        DrumInstrument.allCases.forEach { instrument in
            let sampler = AVAudioUnitSampler()
            instrumentStates[instrument] = InstrumentState(sampler: sampler)
            engine.attach(sampler)
            engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
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
    func setKickPreset(_ preset: KickPreset) {
        setPreset(program: preset.program, midiNote: preset.midiNote, instrument: .kick)
    }

    func setSnarePreset(_ preset: SnarePreset) {
        setPreset(program: preset.program, midiNote: preset.midiNote, instrument: .snare)
    }

    func setHiHatPreset(_ preset: HiHatPreset) {
        setPreset(program: preset.program, midiNote: preset.midiNote, instrument: .hiHat)
    }

    func playPreview(for instrument: DrumInstrument) {
        playbackQueue.async {
            self.triggerNote(for: instrument)
        }
    }

    // MARK: - Trigger
    private func triggerNote(for instrument: DrumInstrument) {
        guard let state = instrumentStates[instrument] else { return }
        state.sampler.startNote(state.midiNote, withVelocity: velocity, onChannel: midiChannel)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            state.sampler.stopNote(state.midiNote, onChannel: self.midiChannel)
        }
    }

    // MARK: - Transport
    func start(bpm: Double, tracksByInstrument: [DrumInstrument: [KickTrack]]) {
        playbackQueue.async {
            guard !self.isRunningInternal, bpm > 0, !tracksByInstrument.isEmpty else { return }

            self.baseBpm = bpm
            self.isRunningInternal = true
            self.updateIsRunning(true)

            tracksByInstrument.forEach { instrument, tracks in
                self.configureInstrument(instrument, tracks: tracks)
            }
        }
    }

    func updateInstrumentTracks(_ instrument: DrumInstrument, tracks: [KickTrack]) {
        playbackQueue.async {
            self.updateInstrumentTracksOnQueue(instrument, tracks: tracks)
        }
    }

    func stop() {
        playbackQueue.async {
            self.stopOnQueue()
        }
    }

    // MARK: - Timer control
    private func startInstrumentTimer(for instrument: DrumInstrument, startImmediately: Bool = true) {
        stopInstrumentTimer(for: instrument)

        guard let state = instrumentStates[instrument], !state.tracks.isEmpty else { return }

        let track = state.tracks[state.currentTrackIndex]
        let effectiveBpm = max(1, baseBpm * track.speedMultiplier)
        let interval = 60.0 / effectiveBpm

        let timer = DispatchSource.makeTimerSource(queue: playbackQueue)
        let deadline: DispatchTime = startImmediately ? .now() : .now() + interval
        timer.schedule(deadline: deadline, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self, let state = self.instrumentStates[instrument], !state.tracks.isEmpty else { return }

            let pattern = state.tracks[state.currentTrackIndex].pattern
            let safePatternLength = max(pattern.count, 1)

            if pattern.indices.contains(state.currentStepIndex),
               pattern[state.currentStepIndex] {
                self.triggerNote(for: instrument)
            }

            let nextStep = state.currentStepIndex + 1
            if nextStep >= safePatternLength {
                state.currentStepIndex = 0
                if state.currentTrackRepeatRemaining > 1 {
                    state.currentTrackRepeatRemaining -= 1
                } else {
                    state.currentTrackIndex = (state.currentTrackIndex + 1) % state.tracks.count
                    self.updateCurrentTrackIndex(for: instrument, value: state.currentTrackIndex)
                    state.currentTrackRepeatRemaining = max(
                        1,
                        state.tracks[state.currentTrackIndex].repeatCount
                    )
                }
                self.startInstrumentTimer(for: instrument, startImmediately: false)
            } else {
                state.currentStepIndex = nextStep
            }
        }

        state.timer = timer
        timer.resume()
    }

    private func stopInstrumentTimer(for instrument: DrumInstrument) {
        instrumentStates[instrument]?.timer?.cancel()
        instrumentStates[instrument]?.timer = nil
    }

    private func stopOnQueue() {
        isRunningInternal = false
        updateIsRunning(false)
        instrumentStates.keys.forEach { instrument in
            stopInstrumentTimer(for: instrument)
            updateCurrentTrackIndex(for: instrument, value: nil)
        }
        instrumentStates.values.forEach { state in
            state.currentTrackIndex = 0
            state.currentStepIndex = 0
            state.currentTrackRepeatRemaining = 1
            state.tracks = []
            state.sampler.sendController(123, withValue: 0, onChannel: midiChannel)
        }
    }

    private func updateIsRunning(_ value: Bool) {
        DispatchQueue.main.async {
            self.isRunning = value
        }
    }

    private func updateCurrentTrackIndex(for instrument: DrumInstrument, value: Int?) {
        DispatchQueue.main.async {
            self.currentTrackIndices[instrument] = value
        }
    }

    // MARK: - Instrument setup
    private func setPreset(program: UInt8, midiNote: UInt8, instrument: DrumInstrument) {
        playbackQueue.async {
            guard let state = self.instrumentStates[instrument] else { return }
            if program != state.program {
                self.setDrumKitProgram(for: instrument, program: program)
            }
            state.midiNote = midiNote
        }
    }

    private func setDrumKitProgram(for instrument: DrumInstrument, program: UInt8) {
        guard let url = sf2URL, let state = instrumentStates[instrument] else { return }

        do {
            try state.sampler.loadSoundBankInstrument(
                at: url,
                program: program,
                bankMSB: UInt8(kAUSampler_DefaultPercussionBankMSB),
                bankLSB: 0
            )
            state.program = program
            print("✅ Drum kit loaded program:", program, "for", instrument.rawValue)
        } catch {
            print("❌ Failed to load drum kit program \(program) for \(instrument.rawValue):", error)
        }
    }

    private func configureInstrument(_ instrument: DrumInstrument, tracks: [KickTrack]) {
        guard let state = instrumentStates[instrument] else { return }
        state.tracks = tracks
        guard !tracks.isEmpty else {
            updateCurrentTrackIndex(for: instrument, value: nil)
            return
        }

        state.currentTrackIndex = 0
        state.currentStepIndex = 0
        updateCurrentTrackIndex(for: instrument, value: 0)
        state.currentTrackRepeatRemaining = max(1, tracks[0].repeatCount)
        startInstrumentTimer(for: instrument)
    }

    private func updateInstrumentTracksOnQueue(_ instrument: DrumInstrument, tracks: [KickTrack]) {
        guard let state = instrumentStates[instrument] else { return }
        state.tracks = tracks
        if isRunningInternal {
            if tracks.isEmpty {
                stopInstrumentTimer(for: instrument)
                updateCurrentTrackIndex(for: instrument, value: nil)
            } else {
                if state.currentTrackIndex >= tracks.count {
                    state.currentTrackIndex = 0
                    state.currentStepIndex = 0
                    updateCurrentTrackIndex(for: instrument, value: 0)
                }
                state.currentTrackRepeatRemaining = max(1, tracks[state.currentTrackIndex].repeatCount)
                startInstrumentTimer(for: instrument)
            }
            refreshRunningState()
        }
    }

    private func refreshRunningState() {
        let hasActiveTracks = instrumentStates.values.contains { !$0.tracks.isEmpty }
        if !hasActiveTracks {
            stopOnQueue()
        }
    }
}
}
