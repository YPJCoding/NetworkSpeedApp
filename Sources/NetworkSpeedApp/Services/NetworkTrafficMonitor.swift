import Darwin
import Foundation

enum NetworkTrafficMonitorError: LocalizedError {
    case sizeQueryFailed(Int32)
    case readFailed(Int32)
    case malformedMessage

    var errorDescription: String? {
        switch self {
        case .sizeQueryFailed(let code): "无法查询网络接口数据大小（errno: \(code)）"
        case .readFailed(let code): "无法读取网络接口数据（errno: \(code)）"
        case .malformedMessage: "系统返回了无效的网络接口消息"
        }
    }
}

struct NetworkTrafficMonitor: Sendable {
    func snapshot() throws -> NetworkTrafficSnapshot {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var byteCount = 0

        guard sysctl(&mib, u_int(mib.count), nil, &byteCount, nil, 0) == 0 else {
            throw NetworkTrafficMonitorError.sizeQueryFailed(errno)
        }
        guard byteCount > 0 else { return NetworkTrafficSnapshot(interfaces: [:]) }

        var buffer = [UInt8](repeating: 0, count: byteCount)
        let result = buffer.withUnsafeMutableBytes { rawBuffer in
            sysctl(&mib, u_int(mib.count), rawBuffer.baseAddress, &byteCount, nil, 0)
        }
        guard result == 0 else { throw NetworkTrafficMonitorError.readFailed(errno) }

        var interfaces: [String: InterfaceTraffic] = [:]
        var offset = 0
        while offset < byteCount {
            let commonHeaderSize = MemoryLayout<UInt16>.size + 2 * MemoryLayout<UInt8>.size
            guard byteCount - offset >= commonHeaderSize else {
                throw NetworkTrafficMonitorError.malformedMessage
            }

            let messageLength: Int = buffer.withUnsafeBytes {
                Int($0.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
            }
            let messageType = buffer[offset + 3]
            guard messageLength >= commonHeaderSize, messageLength <= byteCount - offset else {
                throw NetworkTrafficMonitorError.malformedMessage
            }

            if Int32(messageType) == RTM_IFINFO2,
               messageLength >= MemoryLayout<if_msghdr2>.size {
                let header: if_msghdr2 = buffer.withUnsafeBytes {
                    $0.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                }
                if let name = interfaceName(index: header.ifm_index),
                   NetworkInterfacePolicy.isPhysical(name),
                   (header.ifm_flags & IFF_LOOPBACK) == 0 {
                    interfaces[name] = InterfaceTraffic(
                        name: name,
                        receivedBytes: UInt64(header.ifm_data.ifi_ibytes),
                        sentBytes: UInt64(header.ifm_data.ifi_obytes),
                        isUp: (header.ifm_flags & IFF_UP) != 0,
                        isRunning: (header.ifm_flags & IFF_RUNNING) != 0
                    )
                }
            }
            offset += messageLength
        }
        return NetworkTrafficSnapshot(interfaces: interfaces)
    }

    private func interfaceName(index: UInt16) -> String? {
        var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
        guard if_indextoname(UInt32(index), &name) != nil else { return nil }
        let bytes = name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
