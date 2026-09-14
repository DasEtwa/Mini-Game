import AVFoundation
import TycoonCore

/// One serial audio channel, one retained player. Rapid taps restart instead of accumulating voices.
final class PurchaseAudio: @unchecked Sendable {
    private let queue = DispatchQueue(label: "RackAndRich.audio", qos: .userInitiated)
    private var player: AVAudioPlayer?
    private var gate = AudioGate()
    func play(enabled: Bool) {
        queue.async { [self] in
            guard enabled else { player?.stop(); return }
            guard gate.trigger(at: ProcessInfo.processInfo.systemUptime) else { return }
            if player == nil {
                try? AVAudioSession.sharedInstance().setCategory(.ambient)
                player = try? AVAudioPlayer(data: Self.chime)
                player?.prepareToPlay()
            }
            player?.stop()
            player?.currentTime = 0
            player?.volume = 0.55
            player?.play()
        }
    }
    private static let chime = makeChime()
    private static func makeChime() -> Data {
        var data = Data()
        func word(_ value: UInt32, bytes: Int) { for i in 0..<bytes { data.append(UInt8((value >> (8*i)) & 255)) } }
        let count = 3970
        data.append(contentsOf: "RIFF".utf8); word(UInt32(36+count*2), bytes: 4)
        data.append(contentsOf: "WAVEfmt ".utf8); word(16, bytes: 4); word(1, bytes: 2); word(1, bytes: 2)
        word(44100, bytes: 4); word(88200, bytes: 4); word(2, bytes: 2); word(16, bytes: 2)
        data.append(contentsOf: "data".utf8); word(UInt32(count*2), bytes: 4)
        for i in 0..<count {
            let phase = Double(i) * (2.0 * Double.pi * 660.0 / 44100.0)
            let envelope = 1.0 - Double(i) / Double(count)
            let sample = Int16(sin(phase) * 2500.0 * envelope)
            word(UInt32(UInt16(bitPattern: sample)), bytes: 2)
        }
        return data
    }
}
