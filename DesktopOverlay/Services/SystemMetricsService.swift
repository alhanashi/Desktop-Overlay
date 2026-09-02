import Darwin
import Foundation
import IOKit
import IOKit.ps

/// Thin wrappers over the public macOS APIs that expose raw system counters.
/// Every call returns `nil` on failure so callers can degrade to `.unavailable`
/// rather than crash (spec §20 — public APIs only; §27 — error handling).
enum SystemMetricsService {

    // MARK: - CPU (Mach: host_statistics / HOST_CPU_LOAD_INFO)

    static func cpuTicks() -> CPUTicks? {
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        var info = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        // cpu_ticks tuple order: USER, SYSTEM, IDLE, NICE
        return CPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    // MARK: - Memory (Mach: host_statistics64 / HOST_VM_INFO64)

    static let pageSize: UInt64 = {
        var size: vm_size_t = 0
        host_page_size(mach_host_self(), &size)
        return size == 0 ? 4096 : UInt64(size)
    }()

    static func memorySample() -> MemorySample? {
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        var stats = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return MemorySample(
            active: UInt64(stats.active_count),
            wired: UInt64(stats.wire_count),
            compressed: UInt64(stats.compressor_page_count),
            free: UInt64(stats.free_count),
            inactive: UInt64(stats.inactive_count)
        )
    }

    /// `kern.memorystatus_vm_pressure_level`: 1 normal, 2 warning, 4 critical.
    static func memoryPressure() -> MemoryPressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 {
            return MemoryPressure(rawValue: Int(level)) ?? .normal
        }
        return .normal
    }

    // MARK: - Disk I/O (IOKit: IOBlockStorageDriver "Statistics")

    static func diskIOBytes() -> (read: UInt64, write: UInt64)? {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0
        var found = false

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var unmanagedProps: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &unmanagedProps, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let props = unmanagedProps?.takeRetainedValue() as? [String: Any],
               // Key names from <IOKit/storage/IOBlockStorageDriver.h>; the
               // constants themselves are not exposed to Swift.
               let stats = props["Statistics"] as? [String: Any] {
                if let read = (stats["Bytes (Read)"] as? NSNumber)?.uint64Value {
                    totalRead &+= read
                    found = true
                }
                if let write = (stats["Bytes (Write)"] as? NSNumber)?.uint64Value {
                    totalWrite &+= write
                    found = true
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return found ? (totalRead, totalWrite) : nil
    }

    // MARK: - Network (POSIX: getifaddrs / if_data)

    static func networkBytes() -> (received: UInt64, sent: UInt64)? {
        var addrList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrList) == 0, let first = addrList else { return nil }
        defer { freeifaddrs(addrList) }

        var received: UInt64 = 0
        var sent: UInt64 = 0

        var node: UnsafeMutablePointer<ifaddrs>? = first
        while let current = node {
            defer { node = current.pointee.ifa_next }

            let flags = Int32(current.pointee.ifa_flags)
            guard flags & IFF_UP == IFF_UP else { continue }
            guard let sockaddr = current.pointee.ifa_addr,
                  sockaddr.pointee.sa_family == UInt8(AF_LINK) else { continue }

            let name = String(cString: current.pointee.ifa_name)
            guard name != "lo0" else { continue }

            if let raw = current.pointee.ifa_data {
                let data = raw.assumingMemoryBound(to: if_data.self).pointee
                received &+= UInt64(data.ifi_ibytes)
                sent &+= UInt64(data.ifi_obytes)
            }
        }
        return (received, sent)
    }

    // MARK: - Thermal (Foundation: ProcessInfo.thermalState)

    static var thermalState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }

    // MARK: - Battery (IOKit Power Sources) — optional, off by default

    static func batteryPercentage() -> (percent: Double, isCharging: Bool)? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
            else { continue }

            let current = (description[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue
            let maximum = (description[kIOPSMaxCapacityKey] as? NSNumber)?.doubleValue
            guard let current, let maximum, maximum > 0 else { continue }

            let charging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            return ((current / maximum * 100).clamped(to: 0...100), charging)
        }
        return nil
    }
}
