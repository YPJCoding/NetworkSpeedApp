import Darwin
import Foundation

@main
@MainActor
struct NetworkSpeedAppTestRunner {
    private static var failures = 0

    static func main() throws {
        testFirstSample()
        testActualElapsedTime()
        testCounterBeyondFourGiB()
        testCounterReset()
        testAggregatesAllPhysicalInterfaces()
        testIgnoresTunnelAndVirtualInterfaces()
        testNewAndInactiveInterfaces()
        testInvalidIntervals()
        testZeroGapSmoothing()
        testFormatting()
        testMenuBarIconRenderer()
        try testLiveReader()

        guard failures == 0 else {
            print("测试失败：\(failures) 项")
            Darwin.exit(1)
        }
        print("全部测试通过")
    }

    private static func interface(
        _ name: String,
        received: UInt64,
        sent: UInt64,
        up: Bool = true,
        running: Bool = true
    ) -> InterfaceTraffic {
        InterfaceTraffic(name: name, receivedBytes: received, sentBytes: sent, isUp: up, isRunning: running)
    }

    private static func snapshot(_ interfaces: InterfaceTraffic...) -> NetworkTrafficSnapshot {
        NetworkTrafficSnapshot(interfaces: Dictionary(uniqueKeysWithValues: interfaces.map { ($0.name, $0) }))
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            failures += 1
            print("失败：\(message)")
        }
    }

    private static func calculate(
        previous: NetworkTrafficSnapshot?,
        current: NetworkTrafficSnapshot,
        elapsed: TimeInterval = 1,
        maximumExpectedInterval: TimeInterval = 3
    ) -> TrafficCalculation {
        NetworkSpeedCalculator.calculate(
            previous: previous,
            current: current,
            elapsed: elapsed,
            maximumExpectedInterval: maximumExpectedInterval
        )
    }

    private static func testFirstSample() {
        let result = calculate(previous: nil, current: snapshot(interface("en0", received: 100, sent: 50)))
        expect(!result.hasValidSample && result.speed == .zero, "首次采样只建立基线")
    }

    private static func testActualElapsedTime() {
        let result = calculate(
            previous: snapshot(interface("en0", received: 1_000, sent: 2_000)),
            current: snapshot(interface("en0", received: 5_000, sent: 3_000)),
            elapsed: 2
        )
        expect(result.speed.downloadBytesPerSecond == 2_000, "按实际时间计算下载速度")
        expect(result.speed.uploadBytesPerSecond == 500, "按实际时间计算上传速度")
        expect(result.receivedDelta == 4_000 && result.sentDelta == 1_000, "计算字节增量")
    }

    private static func testCounterBeyondFourGiB() {
        let base = UInt64(UInt32.max) + 10_000
        let result = calculate(
            previous: snapshot(interface("en0", received: base, sent: base)),
            current: snapshot(interface("en0", received: base + 8_000, sent: base + 4_000))
        )
        expect(result.receivedDelta == 8_000 && result.sentDelta == 4_000, "支持超过 4 GiB 的计数器")
    }

    private static func testCounterReset() {
        let result = calculate(
            previous: snapshot(interface("en0", received: 10_000, sent: 20_000)),
            current: snapshot(interface("en0", received: 100, sent: 200))
        )
        expect(!result.hasValidSample && result.speed == .zero, "单网卡计数器回退时丢弃差值")

        let unaffected = calculate(
            previous: snapshot(
                interface("en0", received: 10_000, sent: 10_000),
                interface("en1", received: 1_000, sent: 1_000)
            ),
            current: snapshot(
                interface("en0", received: 100, sent: 100),
                interface("en1", received: 1_500, sent: 1_300)
            )
        )
        expect(unaffected.receivedDelta == 500 && unaffected.sentDelta == 300, "单网卡计数器回退不影响其他网卡")
    }

    private static func testAggregatesAllPhysicalInterfaces() {
        let previous = snapshot(
            interface("en0", received: 1_000, sent: 2_000),
            interface("en1", received: 10_000, sent: 20_000)
        )
        let current = snapshot(
            interface("en0", received: 5_000, sent: 3_000),
            interface("en1", received: 11_000, sent: 22_000)
        )
        let result = calculate(previous: previous, current: current)
        expect(result.receivedDelta == 5_000, "汇总所有物理网卡下载增量")
        expect(result.sentDelta == 3_000, "汇总所有物理网卡上传增量")
        expect(result.speed.downloadBytesPerSecond == 5_000, "汇总多网卡下载速度")
        expect(result.speed.uploadBytesPerSecond == 3_000, "汇总多网卡上传速度")
    }

    private static func testIgnoresTunnelAndVirtualInterfaces() {
        let previous = snapshot(
            interface("en0", received: 1_000, sent: 1_000),
            interface("utun3", received: 50_000, sent: 40_000),
            interface("lo0", received: 80_000, sent: 80_000),
            interface("bridge100", received: 90_000, sent: 90_000)
        )
        let current = snapshot(
            interface("en0", received: 2_000, sent: 1_500),
            interface("utun3", received: 5_050_000, sent: 4_040_000),
            interface("lo0", received: 8_080_000, sent: 8_080_000),
            interface("bridge100", received: 9_090_000, sent: 9_090_000)
        )
        let result = calculate(previous: previous, current: current)
        expect(result.receivedDelta == 1_000 && result.sentDelta == 500, "忽略 utun、回环和 bridge，避免重复计数")
        expect(!NetworkInterfacePolicy.isPhysical("utun3"), "TUN 接口不属于物理网卡")
        expect(!NetworkInterfacePolicy.isPhysical("bridge100"), "bridge 不属于物理网卡")
    }

    private static func testNewAndInactiveInterfaces() {
        let newlyAdded = calculate(
            previous: snapshot(interface("en0", received: 100, sent: 100)),
            current: snapshot(
                interface("en0", received: 200, sent: 200),
                interface("en1", received: 9_000, sent: 9_000)
            )
        )
        expect(newlyAdded.receivedDelta == 100, "新网卡首个采样周期只建立基线")

        let inactive = calculate(
            previous: snapshot(interface("en0", received: 100, sent: 100)),
            current: snapshot(interface("en0", received: 200, sent: 200, running: false))
        )
        expect(!inactive.hasValidSample, "非运行网卡不产生速度")

        let onlyTunnel = calculate(
            previous: snapshot(interface("utun3", received: 100, sent: 100)),
            current: snapshot(interface("utun3", received: 200, sent: 200))
        )
        expect(!onlyTunnel.hasValidSample, "没有物理网卡时不统计隧道流量")
    }

    private static func testInvalidIntervals() {
        for elapsed in [0.0, 0.01, 5.0] {
            let result = calculate(
                previous: snapshot(interface("en0", received: 100, sent: 100)),
                current: snapshot(interface("en0", received: 200, sent: 200)),
                elapsed: elapsed
            )
            expect(!result.hasValidSample, "拒绝异常采样间隔 \(elapsed)")
        }
    }

    private static func testZeroGapSmoothing() {
        var smoother = NetworkSpeedSmoother()
        let active = NetworkSpeed(downloadBytesPerSecond: 1_000, uploadBytesPerSecond: 400)
        expect(smoother.append(active, duration: 1, window: 2) == active, "平滑器保留首个有效样本")

        let afterOneIdleSample = smoother.append(.zero, duration: 1, window: 3)
        expect(afterOneIdleSample.downloadBytesPerSecond == 500, "单次零流量采样不会让下载速度骤降为零")
        expect(afterOneIdleSample.uploadBytesPerSecond == 200, "上传速度使用相同的滚动时间窗")

        let afterTwoIdleSamples = smoother.append(.zero, duration: 1, window: 3)
        expect(afterTwoIdleSamples.downloadBytesPerSecond > 0, "两秒短暂空档仍由近期流量平滑")
        let afterThreeIdleSamples = smoother.append(.zero, duration: 1, window: 3)
        expect(afterThreeIdleSamples == .zero, "持续无流量时滚动窗口最终归零")
    }

    private static func testFormatting() {
        expect(TrafficFormatter.speed(0) == "0 KB/s", "零速度使用最小单位 KB/s")
        expect(TrafficFormatter.speed(9 * 1024) == "0 KB/s", "低于 10 KB/s 时归零显示")
        expect(TrafficFormatter.speed(10 * 1024) == "10.0 KB/s", "10 KB/s 开始显示")
        expect(TrafficFormatter.speed(1024) == "0 KB/s", "低速值按阈值归零")
        expect(TrafficFormatter.speed(1024 * 1024) == "1.0 MB/s", "格式化 MB/s 且最多一位小数")
        expect(TrafficFormatter.speed(512 * 1024 * 1024) == "512 MB/s", "大数值使用紧凑格式")
        expect(TrafficFormatter.speed(1024 * 1024 * 1024) == "1.0 GB/s", "格式化 GB/s 且最多一位小数")
        expect(TrafficFormatter.speed(128 * 1024 * 1024 * 1024) == "128 GB/s", "大流量 GB/s 使用紧凑格式")
    }

    private static func testMenuBarIconRenderer() {
        let image = MenuBarIconRenderer.twoLine(upload: "1.2 MB/s", download: "8.5 MB/s")
        expect(image.size == .init(width: 61, height: 22), "双行状态栏图片尺寸正确")
        expect(image.isTemplate, "状态栏图片使用系统模板着色")
        expect(image.tiffRepresentation != nil, "双行状态栏图片可正常绘制")
    }

    private static func testLiveReader() throws {
        let snapshot = try NetworkTrafficMonitor().snapshot()
        expect(!snapshot.interfaces.isEmpty, "读取实时物理网络接口")
        expect(snapshot.interfaces.values.allSatisfy { $0.isPhysical }, "采集结果只包含物理网卡")
    }
}
