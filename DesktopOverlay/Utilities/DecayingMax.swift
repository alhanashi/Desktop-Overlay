import Foundation

/// Tracks a slowly-decaying maximum, used to normalise unbounded rate values
/// (disk / network bytes-per-second) into a 0...1 range for the sparklines.
/// The decay lets the graph re-scale after a burst instead of staying flat.
struct DecayingMax {
    private(set) var value: Double
    private let decay: Double
    private let floor: Double

    init(initial: Double = 1, decay: Double = 0.95, floor: Double = 1) {
        self.value = Swift.max(initial, floor)
        self.decay = decay
        self.floor = floor
    }

    /// Feed a new observation and return it normalised against the current max.
    mutating func normalise(_ observation: Double) -> Double {
        value = Swift.max(value * decay, observation, floor)
        guard value > 0 else { return 0 }
        return (observation / value).clamped(to: 0...1)
    }
}
