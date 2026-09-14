import SwiftUI
import TycoonCore
import AVFoundation

@MainActor final class GameStore: ObservableObject {
    @Published var game = GameState()
    @Published var message: String?
    @Published var saveProblem: String?
    @Published var loading = true
    @Published var paused = false
    @Published var speed = 1
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var remainder = 0.0
    private var ticks = 0
    private var active = false
    private var player: AVAudioPlayer?
    private let saveURL: URL
    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("RackAndRich", isDirectory: true)
        saveURL = folder.appendingPathComponent("save-v1.json")
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            saveURLOverrideReset()
            paused = true
        }
    }
    private func saveURLOverrideReset() {
        // Only the simulator's test sandbox; never enabled by the production UI.
        #if DEBUG
        try? FileManager.default.removeItem(at: saveURL)
        try? FileManager.default.removeItem(at: saveURL.appendingPathExtension("backup"))
        #endif
    }
    func activate() {
        guard !active else { return }
        active = true; loading = true
        let url = saveURL
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) { () throws -> (GameState, Int, Bool) in
                    var state: GameState
                    var recovered = false
                    if FileManager.default.fileExists(atPath: url.path) {
                        do { state = try SaveStore.load(from: url) }
                        catch {
                            // Keep future versions intact; recovery is offered explicitly to the player.
                            throw error
                        }
                    } else if FileManager.default.fileExists(atPath: url.appendingPathExtension("backup").path) {
                        state = try SaveStore.load(from: url.appendingPathExtension("backup")); recovered = true
                    } else { state = GameState() }
                    let hours = SaveStore.offline(&state, now: Date())
                    return (state, hours, recovered)
                }.value
                game = result.0
                if result.1 >= 24 { message = "Willkommen zurück! \(result.1/24) Spieltage wurden offline simuliert. Einnahmen werden zum Monatsende ausgezahlt." }
                if result.2 { message = "Sicherung wiederhergestellt." }
                loading = false; lastTick = ProcessInfo.processInfo.systemUptime
                save()
            } catch { saveProblem = error.localizedDescription; loading = false }
        }
    }
    func deactivate() { active = false; if !loading { save() }; lastTick = ProcessInfo.processInfo.systemUptime }
    func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let delta = min(2, max(0, now-lastTick)); lastTick = now
        guard active, !paused, !loading, saveProblem == nil else { return }
        remainder += delta*Double(speed)
        let hours = Int(remainder/(Balance.secondsPerDay/24))
        remainder -= Double(hours)*(Balance.secondsPerDay/24)
        if hours > 0 { Simulation.advance(hours: hours, state: &game) }
        ticks += 1
        if ticks % 20 == 0 { save() }
    }
    func save() {
        guard saveProblem == nil, !loading else { return }
        game.lastSavedAt = max(game.lastSavedAt, Date())
        do { try SaveStore.save(game, to: saveURL) }
        catch { saveProblem = "Speichern fehlgeschlagen: \(error.localizedDescription)" }
    }
    func act(_ action: (inout GameState) throws -> Void) {
        guard !loading, saveProblem == nil else { return }
        do { try action(&game); save(); sound() }
        catch { message = error.localizedDescription }
    }
    func recoverBackup() {
        do {
            game = try SaveStore.load(from: saveURL.appendingPathExtension("backup"))
            // Preserve the unreadable primary for diagnosis before restoring the valid backup.
            if FileManager.default.fileExists(atPath: saveURL.path) {
                let archive = saveURL.appendingPathExtension("damaged-\(Int(Date().timeIntervalSince1970))")
                try FileManager.default.moveItem(at: saveURL, to: archive)
            }
            saveProblem = nil; save(); activateAfterRecovery()
        } catch { message = "Sicherung nicht verfügbar: \(error.localizedDescription)" }
    }
    private func activateAfterRecovery() { lastTick = ProcessInfo.processInfo.systemUptime; loading = false }
    func reset() {
        do {
            for url in [saveURL, saveURL.appendingPathExtension("backup")] where FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.moveItem(at: url, to: url.appendingPathExtension("archived-\(UUID().uuidString)"))
            }
            game = GameState(); saveProblem = nil; loading = false; remainder = 0; save()
        } catch { message = "Neustart fehlgeschlagen: \(error.localizedDescription)" }
    }
    private func sound() {
        guard game.soundEnabled else { return }
        // Original 90 ms sine chime; no audio files or external assets.
        var data = Data()
        func word(_ value: UInt32, bytes: Int) { for i in 0..<bytes { data.append(UInt8((value >> (8*i)) & 255)) } }
        let count = 3970
        data.append(contentsOf: "RIFF".utf8); word(UInt32(36+count*2), bytes: 4)
        data.append(contentsOf: "WAVEfmt ".utf8); word(16, bytes: 4); word(1, bytes: 2); word(1, bytes: 2)
        word(44100, bytes: 4); word(88200, bytes: 4); word(2, bytes: 2); word(16, bytes: 2)
        data.append(contentsOf: "data".utf8); word(UInt32(count*2), bytes: 4)
        for i in 0..<count {
            let sample = Int16(sin(Double(i)*2*Double.pi*660/44100)*2500*(1-Double(i)/Double(count)))
            word(UInt32(UInt16(bitPattern: sample)), bytes: 2)
        }
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        player = try? AVAudioPlayer(data: data); player?.play()
    }
}
