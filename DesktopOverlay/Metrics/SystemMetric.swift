import Foundation

/// A pollable system metric. Implementations must be cheap, must not touch the
/// UI, and must never crash on failure — return `.unavailable` instead
/// (spec §17, §27).
///
/// `sample(interval:)` is always called off the main thread by
/// `MetricsCoordinator`. Implementations may keep private state between calls
/// (e.g. the previous raw counter for rate calculations).
protocol SystemMetric: AnyObject {
    var id: MetricID { get }
    var displayName: String { get }

    /// - Parameter interval: seconds elapsed since the previous call (the real
    ///   measured delta, not the nominal setting).
    func sample(interval: TimeInterval) -> MetricReading
}

extension SystemMetric {
    var displayName: String { id.displayName }
}
