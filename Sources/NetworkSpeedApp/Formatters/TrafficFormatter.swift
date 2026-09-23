import Foundation

enum TrafficFormatter {
    static func speed(_ bytesPerSecond: Double) -> String {
        let value = max(0, bytesPerSecond)
        guard value >= 10 * 1024 else { return "0 KB/s" }

        switch value {
        case ..<(1024 * 1024):
            let kilobytes = value / 1024
            return kilobytes < 100
                ? String(format: "%.1f KB/s", kilobytes)
                : String(format: "%.0f KB/s", kilobytes)
        case ..<(1024 * 1024 * 1024):
            let megabytes = value / (1024 * 1024)
            return megabytes < 100
                ? String(format: "%.1f MB/s", megabytes)
                : String(format: "%.0f MB/s", megabytes)
        default:
            let gigabytes = value / (1024 * 1024 * 1024)
            return gigabytes < 100
                ? String(format: "%.1f GB/s", gigabytes)
                : String(format: "%.0f GB/s", gigabytes)
        }
    }

}
