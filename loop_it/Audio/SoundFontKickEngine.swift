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
    @Published var currentTrackIndex: Int?

    // MARK: - Audio engine plumbing
    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private var stepTimer: DispatchSourceTimer?
    private let playbackQueue = DispatchQueue(label: "SoundFontKickEngine.playback")

    // MARK: - Playback configuration
    private var baseBpm: Double = 120
    var kickSpeedMultiplier: Double = 1.0 // 0.5, 1, 2, 4, ...
    private var isRunningInternal = false

    // MARK: - SoundFont configuration
    private let soundFontName: String
    private let soundFontExtension: String

    /// General MIDI drum channel (MIDI ch.10 => index 9).
    var midiChannel: UInt8 = 9

    /// Currently selected drum note (kick, snare, hi-hat, etc.).
    var activeMIDINote: UInt8 = 36
    var velocity: UInt8 = 110

    /// Keep the SF2 URL so we can reload different programs.
    private var sf2URL: URL?
    private var currentProgram: UInt8 = 0

    // MARK: - Sequencing state
    var kickPattern: [Bool] = [true, false, false, false]
    private var kickTracks: [KickTrack] = []
    private var currentTrackIndexInternal: Int = 0
    private var currentStepIndex: Int = 0
    private var currentTrackRepeatRemaining: Int = 1

    init(soundFontName: String = "GeneralUser-GS", soundFontExtension: String = "sf2") {
        self.soundFontName = soundFontName
        self.soundFontExtension = soundFontExtension

        setupAudio()
        loadSoundFontURL()

        // Default kit: Standard 1.
        setDrumKitProgram(0)
    }

    // MARK: - Setup
    private func setupAudio() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

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
    func setDrumKitProgram(_ program: UInt8) {
        guard let url = sf2URL else { return }

        do {
            try sampler.loadSoundBankInstrument(
                at: url,
                program: program,
                bankMSB: UInt8(kAUSampler_DefaultPercussionBankMSB),
                bankLSB: 0
            )
            currentProgram = program
            print("✅ Drum kit loaded program:", program)
        } catch {
            print("❌ Failed to load drum kit program \(program):", error)
        }
    }

    // MARK: - Presets
    func setKickPreset(_ preset: KickPreset) {
        playbackQueue.async {
            // Reload kit only if needed.
            if preset.program != self.currentProgram {
                self.setDrumKitProgram(preset.program)
            }
            // Update active note.
            self.activeMIDINote = preset.midiNote
        }
    }

    func setSnarePreset(_ preset: SnarePreset) {
        playbackQueue.async {
            if preset.program != self.currentProgram {
                self.setDrumKitProgram(preset.program)
            }
            self.activeMIDINote = preset.midiNote
        }
    }

    func setHiHatPreset(_ preset: HiHatPreset) {
        playbackQueue.async {
            if preset.program != self.currentProgram {
                self.setDrumKitProgram(preset.program)
            }
            self.activeMIDINote = preset.midiNote
        }
    }

    func playPreview() {
        playbackQueue.async {
            self.triggerNote()
        }
    }

    // MARK: - Trigger
    private func triggerNote() {
        sampler.startNote(activeMIDINote, withVelocity: velocity, onChannel: midiChannel)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.sampler.stopNote(self.activeMIDINote, onChannel: self.midiChannel)
        }
    }

    // MARK: - Transport
    func start(bpm: Double) {
        start(
            bpm: bpm,
            tracks: [KickTrack(pattern: kickPattern, speedMultiplier: kickSpeedMultiplier, repeatCount: 1)]
        )
    }

    func start(bpm: Double, tracks: [KickTrack]) {
        playbackQueue.async {
            guard !self.isRunningInternal, bpm > 0, !tracks.isEmpty else { return }

            self.baseBpm = bpm
            self.isRunningInternal = true
            self.updateIsRunning(true)
            self.kickTracks = tracks
            self.currentTrackIndexInternal = 0
            self.currentStepIndex = 0
            self.updateCurrentTrackIndex(0)
            self.currentTrackRepeatRemaining = max(1, tracks[0].repeatCount)

            self.startKickTimer()
        }
    }
    
    func setKickSpeedMultiplier(_ newValue: Double) {
        playbackQueue.async {
            // Clamp to sensible values.
            let clamped = min(max(newValue, 0.25), 8.0)
            self.kickSpeedMultiplier = clamped

            // If running, restart timer with new interval.
            if self.isRunningInternal {
                self.updateKickTracksOnQueue([
                    KickTrack(pattern: self.kickPattern, speedMultiplier: self.kickSpeedMultiplier, repeatCount: 1)
                ])
            }
        }
    }

    func updateKickTracks(_ tracks: [KickTrack]) {
        playbackQueue.async {
            self.updateKickTracksOnQueue(tracks)
        }
    }

    func stop() {
        playbackQueue.async {
            self.stopOnQueue()
        }
    }

    // MARK: - Timer control
    private func startKickTimer(startImmediately: Bool = true) {
        stopKickTimer()

        guard !kickTracks.isEmpty else { return }

        let track = kickTracks[currentTrackIndexInternal]
        let effectiveBpm = max(1, baseBpm * track.speedMultiplier)
        let interval = 60.0 / effectiveBpm

        let timer = DispatchSource.makeTimerSource(queue: playbackQueue)
        let deadline: DispatchTime = startImmediately ? .now() : .now() + interval
        timer.schedule(deadline: deadline, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            guard self.kickTracks.indices.contains(self.currentTrackIndexInternal) else {
                return
            }

            let pattern = self.kickTracks[self.currentTrackIndexInternal].pattern
            let safePatternLength = max(pattern.count, 1)

            if pattern.indices.contains(self.currentStepIndex),
               pattern[self.currentStepIndex] {
                self.triggerNote()
            }

            let nextStep = self.currentStepIndex + 1
            if nextStep >= safePatternLength {
                self.currentStepIndex = 0
                if self.currentTrackRepeatRemaining > 1 {
                    self.currentTrackRepeatRemaining -= 1
                } else {
                    self.currentTrackIndexInternal = (self.currentTrackIndexInternal + 1) % self.kickTracks.count
                    self.updateCurrentTrackIndex(self.currentTrackIndexInternal)
                    self.currentTrackRepeatRemaining = max(
                        1,
                        self.kickTracks[self.currentTrackIndexInternal].repeatCount
                    )
                }
                self.startKickTimer(startImmediately: false)
            } else {
                self.currentStepIndex = nextStep
            }
        }

        stepTimer = timer
        timer.resume()
    }

    private func stopKickTimer() {
        stepTimer?.cancel()
        stepTimer = nil
    }

    private func updateKickTracksOnQueue(_ tracks: [KickTrack]) {
        kickTracks = tracks
        if isRunningInternal {
            guard !tracks.isEmpty else {
                stopOnQueue()
                return
            }
            if currentTrackIndexInternal >= tracks.count {
                currentTrackIndexInternal = 0
                currentStepIndex = 0
                updateCurrentTrackIndex(0)
            }
            currentTrackRepeatRemaining = max(1, tracks[currentTrackIndexInternal].repeatCount)
            startKickTimer()
        }
    }

    private func stopOnQueue() {
        isRunningInternal = false
        updateIsRunning(false)
        stopKickTimer()
        updateCurrentTrackIndex(nil)
        currentTrackIndexInternal = 0
        currentStepIndex = 0
        currentTrackRepeatRemaining = 1
        sampler.sendController(123, withValue: 0, onChannel: midiChannel)
    }

    private func updateIsRunning(_ value: Bool) {
        DispatchQueue.main.async {
            self.isRunning = value
        }
    }

    private func updateCurrentTrackIndex(_ value: Int?) {
        DispatchQueue.main.async {
            self.currentTrackIndex = value
        }
    }
}
