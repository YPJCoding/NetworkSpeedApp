import Foundation

struct InterfaceTraffic: Sendable, Equatable {
    let name: String
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let isUp: Bool
    let isRunning: Bool

    var isPhysical: Bool { NetworkInterfacePolicy.isPhysical(name) }
}

struct NetworkTrafficSnapshot: Sendable, Equatable {
    let interfaces: [String: InterfaceTraffic]
}

struct NetworkSpeed: Sendable, Equatable {
    var downloadBytesPerSecond: Double
    var uploadBytesPerSecond: Double

    static let zero = NetworkSpeed(downloadBytesPerSecond: 0, uploadBytesPerSecond: 0)
}

struct TrafficCalculation: Sendable, Equatable {
    let speed: NetworkSpeed
    let receivedDelta: UInt64
    let sentDelta: UInt64
    let hasValidSample: Bool
}
