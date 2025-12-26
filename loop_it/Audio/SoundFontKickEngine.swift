import Foundation
import AVFoundation

/// A single pattern lane with its own step sequence and playback speed.
struct KickTrack: Equatable {
    var pattern: [Bool]
    var speedMultiplier: Double
}

@MainActor
final class SoundFontKickEngine: ObservableObject {

    // MARK: - Published state
    @Published var isRunning = false
    @Published var currentTrackIndex: Int?

    // MARK: - Audio engine plumbing
    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private var stepTimer: DispatchSourceTimer?

    // MARK: - Playback configuration
    private var baseBpm: Double = 120
    var kickSpeedMultiplier: Double = 1.0 // 0.5, 1, 2, 4, ...

    // MARK: - SoundFont configuration
    private let soundFontName: String
    private let soundFontExtension: String

    /// General MIDI drum channel (MIDI ch.10 => index 9).
    var midiChannel: UInt8 = 9

    /// Kick note (typically 36 or 35).
    var kickMIDINote: UInt8 = 36
    var velocity: UInt8 = 110

    /// Keep the SF2 URL so we can reload different programs.
    private var sf2URL: URL?
    private var currentProgram: UInt8 = 0

    // MARK: - Sequencing state
    var kickPattern: [Bool] = [true, false, false, false]
    private var kickTracks: [KickTrack] = []
    private var currentTrackIndexInternal: Int = 0
    private var currentStepIndex: Int = 0

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
        // Reload kit only if needed.
        if preset.program != currentProgram {
            setDrumKitProgram(preset.program)
        }
        // Update kick note.
        kickMIDINote = preset.midiNote
    }

    func playKickPreview() {
        triggerKick()
    }

    // MARK: - Trigger
    private func triggerKick() {
        sampler.startNote(kickMIDINote, withVelocity: velocity, onChannel: midiChannel)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.sampler.stopNote(self.kickMIDINote, onChannel: self.midiChannel)
        }
    }

    // MARK: - Transport
    func start(bpm: Double) {
        start(bpm: bpm, tracks: [KickTrack(pattern: kickPattern, speedMultiplier: kickSpeedMultiplier)])
    }

    func start(bpm: Double, tracks: [KickTrack]) {
        guard !isRunning, bpm > 0, !tracks.isEmpty else { return }

        baseBpm = bpm
        isRunning = true
        kickTracks = tracks
        currentTrackIndexInternal = 0
        currentStepIndex = 0
        currentTrackIndex = 0

        startKickTimer()
    }
    
    func setKickSpeedMultiplier(_ newValue: Double) {
        // Clamp to sensible values.
        let clamped = min(max(newValue, 0.25), 8.0)
        kickSpeedMultiplier = clamped

        // If running, restart timer with new interval.
        if isRunning {
            updateKickTracks([KickTrack(pattern: kickPattern, speedMultiplier: kickSpeedMultiplier)])
        }
    }

    func updateKickTracks(_ tracks: [KickTrack]) {
        kickTracks = tracks
        if isRunning {
            guard !tracks.isEmpty else {
                stop()
                return
            }
            if currentTrackIndexInternal >= tracks.count {
                currentTrackIndexInternal = 0
                currentStepIndex = 0
                currentTrackIndex = 0
            }
            startKickTimer()
        }
    }

    func stop() {
        isRunning = false
        stopKickTimer()
        currentTrackIndex = nil
        currentTrackIndexInternal = 0
        currentStepIndex = 0
        sampler.sendController(123, withValue: 0, onChannel: midiChannel)
    }

    // MARK: - Timer control
    private func startKickTimer() {
        stopKickTimer()

        guard !kickTracks.isEmpty else { return }

        let track = kickTracks[currentTrackIndexInternal]
        let effectiveBpm = max(1, baseBpm * track.speedMultiplier)
        let interval = 60.0 / effectiveBpm

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            guard self.kickTracks.indices.contains(self.currentTrackIndexInternal) else {
                return
            }

            let pattern = self.kickTracks[self.currentTrackIndexInternal].pattern
            let safePatternLength = max(pattern.count, 1)

            if pattern.indices.contains(self.currentStepIndex),
               pattern[self.currentStepIndex] {
                self.triggerKick()
            }

            let nextStep = self.currentStepIndex + 1
            if nextStep >= safePatternLength {
                self.currentStepIndex = 0
                self.currentTrackIndexInternal = (self.currentTrackIndexInternal + 1) % self.kickTracks.count
                self.currentTrackIndex = self.currentTrackIndexInternal
                self.startKickTimer()
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
}
