import AppKit
import Combine
import Foundation

@MainActor
final class NetworkSpeedModel: ObservableObject {
    @Published private(set) var speed = NetworkSpeed.zero

    @Published var refreshInterval: Double {
        didSet {
            let valid = Self.allowedIntervals.contains(refreshInterval) ? refreshInterval : 1
            if valid != refreshInterval { refreshInterval = valid; return }
            UserDefaults.standard.set(refreshInterval, forKey: Keys.refreshInterval)
            if monitorTask != nil { restartMonitoring() }
        }
    }


    let loginItemManager = LoginItemManager()
    static let allowedIntervals: [Double] = [0.5, 1, 2, 5]

    private let trafficMonitor = NetworkTrafficMonitor()
    private var monitorTask: Task<Void, Never>?
    private var pathObserver: NetworkPathObserver?
    private var wakeObserver: NSObjectProtocol?
    private var previousSnapshot: NetworkTrafficSnapshot?
    private var previousInstant: ContinuousClock.Instant?
    private var lastPathAvailability: Bool?
    private var speedSmoother = NetworkSpeedSmoother()
    private let clock = ContinuousClock()

    init() {
        let storedInterval = UserDefaults.standard.double(forKey: Keys.refreshInterval)
        refreshInterval = Self.allowedIntervals.contains(storedInterval) ? storedInterval : 1
        UserDefaults.standard.removeObject(forKey: "lockedInterface")
        UserDefaults.standard.removeObject(forKey: "displayMode")
    }

    var uploadText: String { TrafficFormatter.speed(speed.uploadBytesPerSecond) }
    var downloadText: String { TrafficFormatter.speed(speed.downloadBytesPerSecond) }

    func start() {
        guard monitorTask == nil else { return }
        pathObserver = NetworkPathObserver { [weak self] isAvailable in
            guard let self else { return }
            if let previous = self.lastPathAvailability, previous != isAvailable {
                self.resetBaseline()
            }
            self.lastPathAvailability = isAvailable
        }
        pathObserver?.start()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.resetBaseline() }
        }
        restartMonitoring()
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        pathObserver?.stop()
        pathObserver = nil
        lastPathAvailability = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }


    private func restartMonitoring() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                sample()
                do {
                    try await Task.sleep(for: .seconds(refreshInterval))
                } catch {
                    break
                }
            }
        }
    }

    private func sample() {
        let now = clock.now
        do {
            let snapshot = try trafficMonitor.snapshot()
            let elapsed = previousInstant.map { Self.seconds($0.duration(to: now)) } ?? 0
            let maximumExpectedInterval = max(refreshInterval * 3, refreshInterval + 1)
            let calculation = NetworkSpeedCalculator.calculate(
                previous: previousSnapshot,
                current: snapshot,
                elapsed: elapsed,
                maximumExpectedInterval: maximumExpectedInterval
            )
            if elapsed > maximumExpectedInterval {
                speedSmoother.reset()
                speed = .zero
            } else {
                speed = speedSmoother.append(
                    calculation.hasValidSample ? calculation.speed : .zero,
                    duration: elapsed,
                    window: 3
                )
            }
            previousSnapshot = snapshot
            previousInstant = now
        } catch {
            resetBaseline()
        }
    }

    private func resetBaseline() {
        previousSnapshot = nil
        previousInstant = nil
        speedSmoother.reset()
        speed = .zero
    }

    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    private enum Keys {
        static let refreshInterval = "refreshInterval"
    }
}
