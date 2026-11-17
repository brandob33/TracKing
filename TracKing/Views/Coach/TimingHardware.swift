import AVFoundation
import MediaPlayer
import UIKit

/// The coach's timing options, kept between launches. Both are on until turned off.
enum TimingSettings {
    static let restSoundsKey = "timing.restSounds"
    static let volumeButtonsKey = "timing.volumeButtons"

    static var restSounds: Bool {
        UserDefaults.standard.object(forKey: restSoundsKey) as? Bool ?? true
    }

    static var volumeButtons: Bool {
        UserDefaults.standard.object(forKey: volumeButtonsKey) as? Bool ?? true
    }
}

/// Beeps for the rest countdown: one short beep with 10 seconds left, and three when the
/// rest is over. They play through the speaker even when the phone's ringer is switched off,
/// and over any music that's playing.
final class RestSounds {
    private var warning: AVAudioPlayer?
    private var over: AVAudioPlayer?

    func playWarning() {
        guard TimingSettings.restSounds else { return }
        prepare()
        warning?.currentTime = 0
        warning?.play()
    }

    func playRestOver() {
        guard TimingSettings.restSounds else { return }
        prepare()
        over?.currentTime = 0
        over?.play()
    }

    private func prepare() {
        TimingAudio.activate()
        if warning == nil {
            warning = try? AVAudioPlayer(data: Self.tone(beeps: 1, frequency: 880), fileTypeHint: AVFileType.wav.rawValue)
            warning?.prepareToPlay()
        }
        if over == nil {
            over = try? AVAudioPlayer(data: Self.tone(beeps: 3, frequency: 1320), fileTypeHint: AVFileType.wav.rawValue)
            over?.prepareToPlay()
        }
    }

    /// Builds a short WAV file of beeps in memory, so the app doesn't need sound files.
    private static func tone(beeps: Int, frequency: Double) -> Data {
        let sampleRate = 44_100.0
        let beepLength = 0.18
        let gapLength = 0.12
        var samples: [Int16] = []
        for beep in 0..<beeps {
            let count = Int(sampleRate * beepLength)
            for index in 0..<count {
                let time = Double(index) / sampleRate
                // Fade the first and last few milliseconds so the beep doesn't click.
                let fade = min(1, min(time, beepLength - time) / 0.01)
                let value = sin(2 * Double.pi * frequency * time) * 0.8 * fade
                samples.append(Int16(value * Double(Int16.max)))
            }
            if beep < beeps - 1 {
                samples.append(contentsOf: [Int16](repeating: 0, count: Int(sampleRate * gapLength)))
            }
        }

        var data = Data()
        func append<Value: FixedWidthInteger>(_ value: Value) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        let byteCount = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36) + byteCount)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))                    // size of the format chunk
        append(UInt16(1))                     // PCM
        append(UInt16(1))                     // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate) * 2)        // bytes per second
        append(UInt16(2))                     // bytes per sample
        append(UInt16(16))                    // bits per sample
        data.append(contentsOf: Array("data".utf8))
        append(byteCount)
        for sample in samples {
            append(sample)
        }
        return data
    }
}

/// The audio setup shared by the rest beeps and the volume buttons.
enum TimingAudio {
    static func activate() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}

/// Lets the phone's volume buttons work as a Finish button, so the coach can watch the line
/// instead of the screen.
///
/// iOS has no official way to read the volume buttons, so this watches the volume level:
/// a press changes it, we count that as a tap, and put the volume straight back. While it's
/// listening, the volume buttons don't change the volume. It only listens while a timing
/// screen is open.
final class VolumeButtons: NSObject {
    /// Called with the moment of each press.
    var onPress: ((Date) -> Void)?

    private var observation: NSKeyValueObservation?
    private var volumeView: MPVolumeView?
    private var volumeBeforeListening: Float?
    /// The level we hold the volume at, so there's always room to go up or down.
    private let holdLevel: Float = 0.5

    var isListening: Bool { observation != nil }

    func start() {
        guard observation == nil, TimingSettings.volumeButtons else { return }
        TimingAudio.activate()
        let session = AVAudioSession.sharedInstance()
        volumeBeforeListening = session.outputVolume

        // A volume view on screen hides the system's volume pop-up and lets us set the level.
        let view = MPVolumeView(frame: CGRect(x: -3000, y: -3000, width: 10, height: 10))
        view.alpha = 0.01
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        window?.addSubview(view)
        volumeView = view

        setVolume(holdLevel)
        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            let pressedAt = Date()
            guard let level = change.newValue else { return }
            Task { @MainActor in
                self?.volumeChanged(to: level, at: pressedAt)
            }
        }
    }

    func stop() {
        guard observation != nil else { return }
        observation?.invalidate()
        observation = nil
        // Put the volume back where it was, then take the hidden volume view away.
        let view = volumeView
        let level = volumeBeforeListening
        volumeView = nil
        volumeBeforeListening = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let level, let slider = view?.subviews.compactMap({ $0 as? UISlider }).first {
                slider.value = level
            }
            view?.removeFromSuperview()
        }
    }

    private func volumeChanged(to level: Float, at date: Date) {
        // Our own reset back to the hold level shows up here too. Ignore it.
        guard isListening, abs(level - holdLevel) > 0.001 else { return }
        setVolume(holdLevel)
        onPress?(date)
    }

    private func setVolume(_ level: Float) {
        guard let slider = volumeView?.subviews.compactMap({ $0 as? UISlider }).first else { return }
        // The slider isn't ready the instant the view is added.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            slider.value = level
        }
    }
}
