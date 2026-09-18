import SwiftUI
import TycoonCore
import UIKit

@MainActor final class GameStore: ObservableObject {
    @Published var game = GameState()
    @Published var message: String?
    @Published var saveProblem: String?
    @Published var loading = true
    @Published var paused = false
    @Published var speed = 1
    @Published var tutorialRevision = 0
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var remainder = 0.0
    private var ticks = 0
    private var active = false
    private var loadGeneration = 0
    private let saveQueue = DispatchQueue(label: "RackAndRich.save", qos: .utility)
    private let audio = PurchaseAudio()
    private var backgroundSave: UIBackgroundTaskIdentifier = .invalid
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
        loadGeneration += 1
        let generation = loadGeneration
        let url = saveURL
        let queue = saveQueue
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) { () throws -> (GameState, Int, Bool) in
                    queue.sync {} // Finish previous lifecycle writes before reading.
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
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--garage-ui-testing") { state = try UITestFixtures.garage() }
                    if ProcessInfo.processInfo.arguments.contains("--unlock-ui-testing") { state = try UITestFixtures.garage(); state.location = .bedroom; state.racks = [state.racks[0]]; state.cash = 20000; state.milestoneCompleted = false; state.garageOperatingHours = 0; state.customers = state.customers.filter { $0.serverID == state.racks[0].servers[0].id } }
                    #endif
                    let hours = SaveStore.offline(&state, now: Date())
                    return (state, hours, recovered)
                }.value
                guard generation == loadGeneration, active else { return }
                game = result.0
                game.operations.receipts = []
                if result.1 >= 24 { message = "Willkommen zurück! \(result.1/24) Spieltage wurden offline simuliert. Kundenzahlungen, Lagerreparaturen und Mitarbeiter liefen weiter." }
                if result.2 { message = "Sicherung wiederhergestellt." }
                loading = false; lastTick = ProcessInfo.processInfo.systemUptime
                save()
            } catch {
                guard generation == loadGeneration, active else { return }
                saveProblem = error.localizedDescription; loading = false
            }
        }
    }
    func deactivate() {
        active = false; loadGeneration += 1
        if !loading {
            if backgroundSave == .invalid {
                backgroundSave = UIApplication.shared.beginBackgroundTask(withName: "Save game") { [weak self] in
                    Task { @MainActor in self?.finishBackgroundSave() }
                }
            }
            save()
            saveQueue.async { [weak self] in Task { @MainActor in self?.finishBackgroundSave() } }
        }
        lastTick = ProcessInfo.processInfo.systemUptime
    }
    private func finishBackgroundSave() {
        guard backgroundSave != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundSave); backgroundSave = .invalid
    }
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
    func save(reportSuccess: Bool = false) {
        guard saveProblem == nil, !loading else { return }
        game.lastSavedAt = max(game.lastSavedAt, Date())
        let snapshot = game
        let url = saveURL
        // All disk validation, backup and atomic writes run off the UI thread in order.
        let work = DispatchWorkItem { [weak self] in
            do {
                try SaveStore.save(snapshot, to: url)
                if reportSuccess { Task { @MainActor [weak self] in self?.message = "Spielstand lokal gespeichert." } }
            }
            catch {
                let detail = error.localizedDescription
                Task { @MainActor [weak self] in self?.saveProblem = "Speichern fehlgeschlagen: \(detail)" }
            }
        }
        saveQueue.async(execute: work)
    }
    func act(_ action: (inout GameState) throws -> Void) {
        guard !loading, saveProblem == nil else { return }
        do { try action(&game); save(); audio.play(enabled: game.soundEnabled) }
        catch { message = error.localizedDescription }
    }
    func recoverBackup() {
        saveQueue.sync {}
        do {
            game = try SaveStore.load(from: saveURL.appendingPathExtension("backup"))
            _ = SaveStore.offline(&game, now: Date())
            game.operations.receipts = []
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
        saveQueue.sync {}
        do {
            for url in [saveURL, saveURL.appendingPathExtension("backup")] where FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.moveItem(at: url, to: url.appendingPathExtension("archived-\(UUID().uuidString)"))
            }
            game = GameState(); saveProblem = nil; loading = false; remainder = 0; save()
        } catch { message = "Neustart fehlgeschlagen: \(error.localizedDescription)" }
    }

}

#if DEBUG
private enum UITestFixtures {
    static func garage() throws -> GameState {
        var state = GameState()
        state.powerID = "home-max"
        state.cash = 40_000; state.reputation = 60; state.tutorialDismissed = true
        let template = state.requests[0]
        state.requests = []
        state.customers = (0..<12).map { index in
            var customer = template
            customer.id = UUID(); customer.name = "GarageTest\(index)"
            customer.booked = .init(cpu: 0.1, ram: 0.1, storage: 1, network: 0.1)
            customer.contract = CustomerContract(months: 3, hour: 0)
            customer.billing = CustomerBilling(hour: 0)
            customer.monthlyPrice = 250; customer.serverID = state.servers[0].id
            return customer
        }
        try ShopSystem.moveToGarage(&state)
        for _ in 0..<3 { try ShopSystem.buyRack("garage", in: &state) }
        for rack in state.racks.dropFirst() { try ShopSystem.buyServer(in: rack.id, state: &state) }
        Simulation.advance(hours: 24, state: &state)
        return state
    }
}
#endif
