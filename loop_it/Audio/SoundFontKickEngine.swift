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
        let instrument: DrumInstrument
        let sampler: AVAudioUnitSampler
        var midiNote: UInt8
        var program: UInt8
        final class TrackState {
            let track: KickTrack
            var timer: DispatchSourceTimer?
            var currentStepIndex: Int = 0
            var repeatRemaining: Int

            init(track: KickTrack) {
                self.track = track
                self.repeatRemaining = max(1, track.repeatCount)
            }
        }

        var trackStates: [TrackState] = []

        init(instrument: DrumInstrument, sampler: AVAudioUnitSampler, midiNote: UInt8 = 36, program: UInt8 = 0) {
            self.instrument = instrument
            self.sampler = sampler
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
    func setKickPreset(_ preset: KickPreset, for instanceID: UUID) {
        setPreset(program: preset.program, midiNote: preset.midiNote, for: instanceID)
    }

    func setSnarePreset(_ preset: SnarePreset, for instanceID: UUID) {
        setPreset(program: preset.program, midiNote: preset.midiNote, for: instanceID)
    }

    func setHiHatPreset(_ preset: HiHatPreset, for instanceID: UUID) {
        setPreset(program: preset.program, midiNote: preset.midiNote, for: instanceID)
    }

    func playPreview(for instanceID: UUID) {
        playbackQueue.async {
            self.triggerNote(for: instanceID)
        }
    }

    // MARK: - Trigger
    private func triggerNote(for instanceID: UUID) {
        guard let state = instrumentStates[instanceID] else { return }
        state.sampler.startNote(state.midiNote, withVelocity: velocity, onChannel: midiChannel)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            state.sampler.stopNote(state.midiNote, onChannel: self.midiChannel)
        }
    }

    // MARK: - Transport
    func start(bpm: Double, tracksByInstance: [UUID: [KickTrack]]) {
        playbackQueue.async {
            guard !self.isRunningInternal, bpm > 0, !tracksByInstance.isEmpty else { return }

            self.baseBpm = bpm
            self.isRunningInternal = true
            self.updateIsRunning(true)

            self.instrumentStates.keys.forEach { instanceID in
                let tracks = tracksByInstance[instanceID] ?? []
                self.configureInstance(instanceID, tracks: tracks)
            }
        }
    }

    func updateSession(bpm: Double, tracksByInstance: [UUID: [KickTrack]]) {
        playbackQueue.async {
            self.stopOnQueue()
            guard bpm > 0, !tracksByInstance.isEmpty else { return }

            self.baseBpm = bpm
            self.isRunningInternal = true
            self.updateIsRunning(true)

            self.instrumentStates.keys.forEach { instanceID in
                let tracks = tracksByInstance[instanceID] ?? []
                self.configureInstance(instanceID, tracks: tracks)
            }
        }
    }

    func updateInstrumentTracks(_ instanceID: UUID, tracks: [KickTrack]) {
        playbackQueue.async {
            self.updateInstrumentTracksOnQueue(instanceID, tracks: tracks)
        }
    }

    func stop() {
        playbackQueue.async {
            self.stopOnQueue()
        }
    }

    // MARK: - Timer control
    private func startTrackTimer(
        for instanceID: UUID,
        trackIndex: Int,
        startImmediately: Bool = true
    ) {
        guard let state = instrumentStates[instanceID],
              state.trackStates.indices.contains(trackIndex) else { return }

        let trackState = state.trackStates[trackIndex]
        let effectiveBpm = max(1, baseBpm * trackState.track.speedMultiplier)
        let interval = 60.0 / effectiveBpm

        let timer = DispatchSource.makeTimerSource(queue: playbackQueue)
        let deadline: DispatchTime = startImmediately ? .now() : .now() + interval
        timer.schedule(deadline: deadline, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self,
                  let state = self.instrumentStates[instanceID],
                  state.trackStates.indices.contains(trackIndex) else { return }

            let activeTrackState = state.trackStates[trackIndex]
            let pattern = activeTrackState.track.pattern
            let safePatternLength = max(pattern.count, 1)

            if pattern.indices.contains(activeTrackState.currentStepIndex),
               pattern[activeTrackState.currentStepIndex] {
                self.triggerNote(for: instanceID)
            }

            let nextStep = activeTrackState.currentStepIndex + 1
            if nextStep >= safePatternLength {
                activeTrackState.currentStepIndex = 0
                if activeTrackState.repeatRemaining > 1 {
                    activeTrackState.repeatRemaining -= 1
                } else {
                    activeTrackState.repeatRemaining = max(1, activeTrackState.track.repeatCount)
                }
            } else {
                activeTrackState.currentStepIndex = nextStep
            }
        }

        trackState.timer?.cancel()
        trackState.timer = timer
        timer.resume()
    }

    private func stopInstrumentTimer(for instanceID: UUID) {
        instrumentStates[instanceID]?.trackStates.forEach { trackState in
            trackState.timer?.cancel()
            trackState.timer = nil
        }
    }

    private func stopOnQueue() {
        isRunningInternal = false
        updateIsRunning(false)
        instrumentStates.keys.forEach { instanceID in
            stopInstrumentTimer(for: instanceID)
            updateCurrentTrackIndices(for: instanceID, value: [])
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

    private func updateCurrentTrackIndices(for instanceID: UUID, value: Set<Int>) {
        DispatchQueue.main.async {
            self.currentTrackIndices[instanceID] = value
        }
    }

    // MARK: - Instrument setup
    private func setPreset(program: UInt8, midiNote: UInt8, for instanceID: UUID) {
        playbackQueue.async {
            guard let state = self.instrumentStates[instanceID] else { return }
            if program != state.program {
                self.setDrumKitProgram(for: instanceID, program: program)
            }
            state.midiNote = midiNote
        }
    }

    private func setDrumKitProgram(for instanceID: UUID, program: UInt8) {
        guard let url = sf2URL, let state = instrumentStates[instanceID] else { return }

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

    private func configureInstance(_ instanceID: UUID, tracks: [KickTrack]) {
        guard let state = instrumentStates[instanceID] else { return }
        stopInstrumentTimer(for: instanceID)
        state.trackStates = tracks.map { InstrumentState.TrackState(track: $0) }
        guard !tracks.isEmpty else {
            updateCurrentTrackIndices(for: instanceID, value: [])
            return
        }

        updateCurrentTrackIndices(for: instanceID, value: Set(tracks.indices))
        tracks.indices.forEach { index in
            startTrackTimer(for: instanceID, trackIndex: index)
        }
    }

    private func updateInstrumentTracksOnQueue(_ instanceID: UUID, tracks: [KickTrack]) {
        guard let state = instrumentStates[instanceID] else { return }
        stopInstrumentTimer(for: instanceID)
        state.trackStates = tracks.map { InstrumentState.TrackState(track: $0) }
        if isRunningInternal {
            if tracks.isEmpty {
                updateCurrentTrackIndices(for: instanceID, value: [])
            } else {
                updateCurrentTrackIndices(for: instanceID, value: Set(tracks.indices))
                tracks.indices.forEach { index in
                    startTrackTimer(for: instanceID, trackIndex: index)
                }
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

    // MARK: - Instance management
    func syncInstrumentInstances(_ instances: [(UUID, DrumInstrument)]) {
        playbackQueue.async {
            let desiredIDs = Set(instances.map { $0.0 })
            let existingIDs = Set(self.instrumentStates.keys)
            let removedIDs = existingIDs.subtracting(desiredIDs)
            let newInstances = instances.filter { self.instrumentStates[$0.0] == nil }

            removedIDs.forEach { self.removeInstrumentInstanceOnQueue($0) }
            newInstances.forEach { self.addInstrumentInstanceOnQueue(id: $0.0, instrument: $0.1) }
        }
    }

    private func addInstrumentInstanceOnQueue(id: UUID, instrument: DrumInstrument) {
        guard instrumentStates[id] == nil else { return }
        let sampler = AVAudioUnitSampler()
        let state = InstrumentState(instrument: instrument, sampler: sampler)
        instrumentStates[id] = state
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        setDrumKitProgram(for: id, program: 0)
    }

    private func removeInstrumentInstanceOnQueue(_ id: UUID) {
        guard let state = instrumentStates[id] else { return }
        stopInstrumentTimer(for: id)
        state.sampler.sendController(123, withValue: 0, onChannel: midiChannel)
        engine.detach(state.sampler)
        instrumentStates.removeValue(forKey: id)
        updateCurrentTrackIndices(for: id, value: [])
    }
}
