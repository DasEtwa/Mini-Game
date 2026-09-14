/// Sound throttling is independent of gameplay input. The audio owner maintains one voice.
public struct AudioGate: Sendable {
    public static let maximumVoices = 1
    private var last = -Double.infinity
    public init() {}
    public mutating func trigger(at time: Double) -> Bool {
        guard time.isFinite, time - last >= 0.06 else { return false }
        last = time
        return true
    }
}
