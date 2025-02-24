//
//  DeviceInfo.swift
//  HuggingSnap
//
//  Created by Cyril Zakka on 2/24/25.
//

import Foundation
import UIKit

extension UIDevice {
    static func getDeviceInfo() -> String {
        let device = UIDevice.current
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryFormatter = ByteCountFormatter()
        memoryFormatter.allowedUnits = [.useGB]
        memoryFormatter.countStyle = .memory
        let formattedMemory = memoryFormatter.string(fromByteCount: Int64(physicalMemory))
        
        // Get free disk space
        var freeDiskSpace: String = "Unknown"
        if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            do {
                let attributes = try FileManager.default.attributesOfFileSystem(forPath: path)
                if let freeSpace = attributes[.systemFreeSize] as? NSNumber {
                    freeDiskSpace = memoryFormatter.string(fromByteCount: freeSpace.int64Value)
                }
            } catch {
                freeDiskSpace = "Error: \(error.localizedDescription)"
            }
        }
        
        return """
        ---- Device Information ----
        Device: \(device.name)
        Model: \(device.model)
        System: \(device.systemName) \(device.systemVersion)
        Screen: \(screenSize.width) x \(screenSize.height) @ \(scale)x
        
        ---- App Information ----
        App Version: \(appVersion) (\(buildNumber))
        
        ---- System Resources ----
        Total RAM: \(formattedMemory)
        Free Disk Space: \(freeDiskSpace)
        
        ---- Current Process Info ----
        \(getProcessMemoryInfo())
        Available Memory: \(getAvailableMemory())
        """
    }
    
    static func getProcessMemoryInfo() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .memory
            let usedMemory = formatter.string(fromByteCount: Int64(info.resident_size))
            return "Memory Usage: \(usedMemory)"
        } else {
            return "Unable to retrieve memory info"
        }
    }
    
    static func getAvailableMemory() -> String {
        let availableMemory = os_proc_available_memory()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(availableMemory))
    }
}
