import AVFoundation
import AudioToolbox

final class GameAudioEngine {
    private var player: AVAudioPlayer?
    private var tapPlayers: [AVAudioPlayer] = []
    private var currentTapPlayerIndex = 0
    private(set) var isReady: Bool = false
    private var song: SongMetadata
    private var musicVolume: Float = 0.9
    private var sfxVolume: Float = 0.6
    private var hitSoundEnabled: Bool = true
    private var lowLatencyMode: Bool = false

    init(song: SongMetadata) {
        self.song = song
        configureAudioSession()
        prepare(for: song)
        prepareTapSounds()
    }

    func updateSong(_ song: SongMetadata) {
        stop()
        isReady = false
        self.song = song
        prepare(for: song)
    }
    
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            if lowLatencyMode {
                try session.setPreferredIOBufferDuration(0.005)
            }
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            debugLog("✓ Audio session configured for playback")
        } catch {
            debugLog("✗ Audio session setup failed: \(error)")
        }
    }
    
    private func prepare(for song: SongMetadata) {
        isReady = false
        debugLog("DEBUG: Preparing audio for \(song.title) ...")
        var url: URL?

        // Always prefer the app bundle’s shipped audio first (ensures correct asset like Resources/hallelujah.wav).
        if let bundleURL = Bundle.main.url(forResource: song.audioName, withExtension: song.audioExtension) {
            url = bundleURL
            debugLog("✓ Using bundled audio: \(bundleURL.lastPathComponent)")
        }

        // Next, check the Resources.bundle inside the app bundle.
        if url == nil {
            let fileManager = FileManager.default
            if let resourcesBundle = Bundle.main.url(forResource: "Resources", withExtension: "bundle") {
                let bundleTrackURL = resourcesBundle.appendingPathComponent(song.audioName).appendingPathExtension(song.audioExtension)
                if fileManager.fileExists(atPath: bundleTrackURL.path) {
                    url = bundleTrackURL
                    debugLog("✓ Using Resources.bundle audio: \(bundleTrackURL.lastPathComponent)")
                }
            }
        }

        // Finally, fall back to Documents (user-downloaded replacement).
        if url == nil {
            let fileManager = FileManager.default
            let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let docPath = docDir.appendingPathComponent(song.audioName).appendingPathExtension(song.audioExtension)
            if fileManager.fileExists(atPath: docPath.path) {
                url = docPath
                debugLog("✓ Using Documents audio override: \(docPath.lastPathComponent)")
            }
        }

        guard let audioURL = url else {
            debugLog("✗ ERROR: Could not find audio for \(song.title)")
            isReady = false
            return
        }

        // Crash-safe: avoid loading excessively large files (e.g. 200 MB cap)
        let maxAudioBytes = 200 * 1024 * 1024
        if let size = (try? FileManager.default.attributesOfItem(atPath: audioURL.path))?[.size] as? Int, size > maxAudioBytes {
            debugLog("✗ Audio file too large: \(song.title)")
            isReady = false
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: audioURL)
            player?.numberOfLoops = 0
            player?.volume = musicVolume
            player?.prepareToPlay()
            isReady = true
            debugLog("✓ Audio player ready with file: \(audioURL.lastPathComponent)")
        } catch {
            debugLog("✗ Failed to initialize audio player: \(error)")
            isReady = false
        }
    }
    
    private func prepareTapSounds() {
        // Create multiple tap sound players for polyphony
        for _ in 0..<8 {
            if let tapSound = createTapSound() {
                tapPlayers.append(tapSound)
            }
        }
    }
    
    private func createTapSound() -> AVAudioPlayer? {
        // Generate a short beep sound programmatically
        let sampleRate = 44100.0
        let duration = 0.1
        let frequency = 800.0
        let amplitude: Float = 0.3
        
        let frameCount = Int(sampleRate * duration)
        var samples: [Float] = []
        
        for i in 0..<frameCount {
            let time = Double(i) / sampleRate
            let envelope = Float(1.0 - time / duration) // Fade out
            let sineWave = sin(2.0 * .pi * frequency * time)
            let sample = Float(sineWave) * amplitude * envelope
            samples.append(sample)
        }
        
        // Convert to 16-bit PCM
        var pcmData = Data()
        let maxValue = Float(Int16.max)
        for sample in samples {
            let intSample = Int16(sample * maxValue)
            var value = intSample
            let valueData = Data(bytes: &value, count: 2)
            pcmData.append(valueData)
        }
        
        // Create WAV header
        var wavData = Data()
        
        // RIFF header
        let riffBytes = "RIFF".utf8
        wavData.append(contentsOf: riffBytes)
        var fileSize = UInt32(36 + pcmData.count)
        wavData.append(Data(bytes: &fileSize, count: 4))
        let waveBytes = "WAVE".utf8
        wavData.append(contentsOf: waveBytes)
        
        // Format chunk
        let fmtBytes = "fmt ".utf8
        wavData.append(contentsOf: fmtBytes)
        var fmtSize = UInt32(16)
        wavData.append(Data(bytes: &fmtSize, count: 4))
        var audioFormat = UInt16(1) // PCM
        wavData.append(Data(bytes: &audioFormat, count: 2))
        var numChannels = UInt16(1) // Mono
        wavData.append(Data(bytes: &numChannels, count: 2))
        var sampleRateInt = UInt32(sampleRate)
        wavData.append(Data(bytes: &sampleRateInt, count: 4))
        var byteRate = UInt32(sampleRate * 2) // 16-bit mono
        wavData.append(Data(bytes: &byteRate, count: 4))
        var blockAlign = UInt16(2)
        wavData.append(Data(bytes: &blockAlign, count: 2))
        var bitsPerSample = UInt16(16)
        wavData.append(Data(bytes: &bitsPerSample, count: 2))
        
        // Data chunk
        let dataBytes = "data".utf8
        wavData.append(contentsOf: dataBytes)
        var dataSize = UInt32(pcmData.count)
        wavData.append(Data(bytes: &dataSize, count: 4))
        wavData.append(pcmData)
        
        do {
            let player = try AVAudioPlayer(data: wavData)
            player.prepareToPlay()
            player.volume = sfxVolume
            return player
        } catch {
            return nil
        }
    }

    func play(after delay: TimeInterval) {
        guard let player else { return }
        player.currentTime = 0
        player.volume = musicVolume
        if delay > 0 {
            let startTime = player.deviceCurrentTime + delay
            player.play(atTime: startTime)
        } else {
            player.play()
        }
    }

    func stop() {
        player?.stop()
    }
    
    func pause() {
        player?.pause()
    }
    
    func resume() {
        player?.play()
    }
    
    func playTapSound() {
        guard hitSoundEnabled else { return }
        guard !tapPlayers.isEmpty else { return }
        let player = tapPlayers[currentTapPlayerIndex]
        player.currentTime = 0
        player.play()
        currentTapPlayerIndex = (currentTapPlayerIndex + 1) % tapPlayers.count
    }

    @MainActor
    func applySettings(_ settings: SettingsManager) {
        musicVolume = Float(settings.musicVolume)
        sfxVolume = Float(settings.sfxVolume)
        hitSoundEnabled = settings.hitSoundEnabled

        if lowLatencyMode != settings.lowLatencyMode {
            lowLatencyMode = settings.lowLatencyMode
            configureAudioSession()
        }

        player?.volume = musicVolume
        for tapPlayer in tapPlayers {
            tapPlayer.volume = sfxVolume
        }
    }

    var currentTime: TimeInterval {
        player?.currentTime ?? 0
    }
    
    var isPlaying: Bool {
        player?.isPlaying ?? false
    }
}
