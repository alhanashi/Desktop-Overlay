import AppKit
import Combine
import Foundation

/// Drives all metric sampling on a single background timer and publishes
/// immutable snapshots to the UI (spec §7, §8, §21).
///
/// - Data is collected off the main thread; the UI is touched only when a new
///   frame is ready.
/// - The timer never fires faster than the user-chosen interval (1 / 2 / 5 s).
/// - Under thermal pressure the effective interval is stretched and sparkline
///   updates are paused, so the app does *less* work when the system is hot.
@MainActor
final class MetricsCoordinator: ObservableObject {

    static let historyLength = 60

    /// Latest reading per metric. Absent key ⇒ metric disabled or never sampled.
    @Published private(set) var readings: [MetricID: MetricReading] = [:]
    /// Sparkline samples per metric, oldest → newest, normalised 0...1.
    @Published private(set) var history: [MetricID: [Double]] = [:]

    private let settings: SettingsStore
    private let queue = DispatchQueue(label: "com.alhanashi.desktopoverlay.metrics", qos: .utility)

    private var timer: DispatchSourceTimer?
    private var running = false
    private var paused = false
    private var cancellables = Set<AnyCancellable>()
    private var buffers: [MetricID: RingBuffer<Double>] = [:]

    // MARK: State shared with the background queue

    /// The metric objects keep private mutable state but are only ever touched
    /// on `queue`, so cross-actor access is safe in practice.
    nonisolated(unsafe) private let metrics: [MetricID: SystemMetric] = [
        .cpu: CPUMetric(),
        .memory: MemoryMetric(),
        .disk: DiskMetric(),
        .network: NetworkMetric(),
        .temperature: ThermalMetric(),
        .battery: BatteryMetric(),
    ]

    nonisolated(unsafe) private var lastTickDate: Date?          // touched only on `queue`
    nonisolated private let configLock = NSLock()
    nonisolated(unsafe) private var _enabled: Set<MetricID> = []
    nonisolated(unsafe) private var _intervalSeconds: TimeInterval = 1

    nonisolated private var enabledSnapshot: Set<MetricID> {
        configLock.lock(); defer { configLock.unlock() }
        return _enabled
    }
    nonisolated private var intervalSecondsSnapshot: TimeInterval {
        configLock.lock(); defer { configLock.unlock() }
        return _intervalSeconds
    }
    nonisolated private func writeConfig(enabled: Set<MetricID>? = nil, interval: TimeInterval? = nil) {
        configLock.lock()
        if let enabled { _enabled = enabled }
        if let interval { _intervalSeconds = interval }
        configLock.unlock()
    }

    // MARK: Init

    init(settings: SettingsStore) {
        self.settings = settings
        for id in MetricID.allCases {
            buffers[id] = RingBuffer(capacity: Self.historyLength)
        }
        writeConfig(enabled: settings.enabledMetrics, interval: settings.updateInterval.seconds)

        settings.$enabledMetrics
            .sink { [weak self] value in
                self?.writeConfig(enabled: value)
                self?.pruneDisabled(keeping: value)
            }
            .store(in: &cancellables)

        settings.$updateInterval
            .removeDuplicates()
            .sink { [weak self] interval in
                self?.writeConfig(interval: interval.seconds)
                self?.rescheduleIfRunning()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rescheduleIfRunning() }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func start() {
        guard !running else { return }
        running = true
        schedule()
        queue.async { [weak self] in self?.tick() }   // sample once immediately
    }

    func stop() {
        running = false
        timer?.cancel()
        timer = nil
    }

    /// Pause collection while the overlay is hidden — no point sampling what
    /// nobody can see (spec §8).
    func setPaused(_ value: Bool) {
        guard value != paused else { return }
        paused = value
        rescheduleIfRunning()
        if !paused, running {
            queue.async { [weak self] in self?.tick() }
        }
    }

    // MARK: - Scheduling (main actor)

    /// Nominal interval from Settings, stretched under thermal pressure (spec §21).
    private var effectiveInterval: TimeInterval {
        let base = settings.updateInterval.seconds
        switch ProcessInfo.processInfo.thermalState {
        case .serious:  return base * 2
        case .critical: return base * 4
        default:        return base
        }
    }

    private func rescheduleIfRunning() {
        guard running else { return }
        schedule()
    }

    private func schedule() {
        timer?.cancel()
        timer = nil
        guard running, !paused else { return }

        let interval = effectiveInterval
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + interval,
                        repeating: interval,
                        leeway: .milliseconds(200))
        source.setEventHandler { [weak self] in self?.tick() }
        timer = source
        source.resume()
    }

    // MARK: - Sampling (runs on `queue`, no actor isolation)

    nonisolated private func tick() {
        let now = Date()
        let elapsed = lastTickDate.map { now.timeIntervalSince($0) } ?? intervalSecondsSnapshot
        lastTickDate = now

        let enabled = enabledSnapshot
        let dropGraphs = ProcessInfo.processInfo.thermalState == .critical

        var frame: [MetricID: MetricReading] = [:]
        for id in MetricID.displayOrder where enabled.contains(id) {
            guard let metric = metrics[id] else { continue }
            frame[id] = metric.sample(interval: elapsed)
        }

        DispatchQueue.main.async { [weak self] in
            self?.publish(frame: frame, enabled: enabled, dropGraphs: dropGraphs)
        }
    }

    // MARK: - Publishing (main actor)

    private func publish(frame: [MetricID: MetricReading],
                         enabled: Set<MetricID>,
                         dropGraphs: Bool) {
        var newReadings = readings
        var newHistory = history

        for id in MetricID.allCases where !enabled.contains(id) {
            newReadings[id] = nil
            newHistory[id] = nil
            buffers[id]?.removeAll()
        }

        for (id, reading) in frame {
            newReadings[id] = reading
            if let sample = reading.graphSample, !dropGraphs {
                buffers[id]?.append(sample)
                newHistory[id] = buffers[id]?.values ?? []
            }
        }

        readings = newReadings
        history = newHistory
    }

    private func pruneDisabled(keeping enabled: Set<MetricID>) {
        for id in MetricID.allCases where !enabled.contains(id) {
            readings[id] = nil
            history[id] = nil
            buffers[id]?.removeAll()
        }
    }
}
