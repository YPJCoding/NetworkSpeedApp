import Foundation

enum NetworkSpeedCalculator {
    static func calculate(
        previous: NetworkTrafficSnapshot?,
        current: NetworkTrafficSnapshot,
        elapsed: TimeInterval,
        maximumExpectedInterval: TimeInterval
    ) -> TrafficCalculation {
        guard let previous,
              elapsed >= 0.05,
              elapsed <= maximumExpectedInterval else {
            return invalidSample
        }

        var receivedDelta: UInt64 = 0
        var sentDelta: UInt64 = 0
        var comparableInterfaces = 0

        for (name, currentTraffic) in current.interfaces {
            guard currentTraffic.isPhysical,
                  currentTraffic.isUp,
                  currentTraffic.isRunning,
                  let previousTraffic = previous.interfaces[name],
                  previousTraffic.isPhysical,
                  previousTraffic.isUp,
                  previousTraffic.isRunning,
                  currentTraffic.receivedBytes >= previousTraffic.receivedBytes,
                  currentTraffic.sentBytes >= previousTraffic.sentBytes else { continue }

            let (newReceivedDelta, receivedOverflow) = receivedDelta.addingReportingOverflow(
                currentTraffic.receivedBytes - previousTraffic.receivedBytes
            )
            let (newSentDelta, sentOverflow) = sentDelta.addingReportingOverflow(
                currentTraffic.sentBytes - previousTraffic.sentBytes
            )
            guard !receivedOverflow, !sentOverflow else { return invalidSample }
            receivedDelta = newReceivedDelta
            sentDelta = newSentDelta
            comparableInterfaces += 1
        }

        guard comparableInterfaces > 0 else { return invalidSample }
        return TrafficCalculation(
            speed: NetworkSpeed(
                downloadBytesPerSecond: Double(receivedDelta) / elapsed,
                uploadBytesPerSecond: Double(sentDelta) / elapsed
            ),
            receivedDelta: receivedDelta,
            sentDelta: sentDelta,
            hasValidSample: true
        )
    }

    private static let invalidSample = TrafficCalculation(
        speed: .zero,
        receivedDelta: 0,
        sentDelta: 0,
        hasValidSample: false
    )
}

struct NetworkSpeedSmoother {
    private struct Sample {
        var duration: TimeInterval
        let speed: NetworkSpeed
    }

    private var samples: [Sample] = []
    private var totalDuration: TimeInterval = 0

    mutating func append(_ speed: NetworkSpeed, duration: TimeInterval, window: TimeInterval) -> NetworkSpeed {
        guard duration > 0, window > 0 else { return average() }
        samples.append(Sample(duration: duration, speed: speed))
        totalDuration += duration

        while totalDuration > window, !samples.isEmpty {
            let excess = totalDuration - window
            if samples[0].duration <= excess {
                totalDuration -= samples.removeFirst().duration
            } else {
                samples[0].duration -= excess
                totalDuration = window
            }
        }
        return average()
    }

    mutating func reset() {
        samples.removeAll(keepingCapacity: true)
        totalDuration = 0
    }

    private func average() -> NetworkSpeed {
        guard totalDuration > 0 else { return .zero }
        let download = samples.reduce(0) { $0 + $1.speed.downloadBytesPerSecond * $1.duration }
        let upload = samples.reduce(0) { $0 + $1.speed.uploadBytesPerSecond * $1.duration }
        return NetworkSpeed(
            downloadBytesPerSecond: download / totalDuration,
            uploadBytesPerSecond: upload / totalDuration
        )
    }
}
