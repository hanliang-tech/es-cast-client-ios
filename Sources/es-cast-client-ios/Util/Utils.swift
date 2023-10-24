//
//  Utils.swift
//
//
//  Created by BM on 2023/10/16.
//

import Foundation
import UIKit

/// 工具类
enum Utils {
    // 获取本机 IP 地址
    static func getIPAddress() -> String? {
        var address: String?

        // Get list of all interfaces on the local machine:
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)

        return address
    }

    // 判断是否为有效的 IP 地址
    static func isValidIPAddress(_ ipAddress: String) -> Bool {
        let ipAddressRegex = #"^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}$"#
        let ipAddressPredicate = NSPredicate(format: "SELF MATCHES %@", ipAddressRegex)
        return ipAddressPredicate.evaluate(with: ipAddress)
    }

    static func deviceInfo() -> [String: Any] {
        // 获取设备信息(手机型号,系统版本,app版本)
        var deviceInfo = [String: Any]()
        deviceInfo["model"] = UIDevice.current.model
        deviceInfo["deviceName"] = DeviceName.getDeviceName()
        deviceInfo["systemVersion"] = UIDevice.current.systemVersion
        deviceInfo["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        deviceInfo["CFBundleDisplayName"] = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
        deviceInfo["bundleVersion"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        deviceInfo["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        deviceInfo["appBundleIdentifier"] = Bundle.main.bundleIdentifier
        deviceInfo["deviceName"] = UIDevice.current.name
        deviceInfo["deviceIsMultitaskingSupported"] = UIDevice.current.isMultitaskingSupported
        deviceInfo["deviceIsGeneratingDeviceOrientationNotifications"] = UIDevice.current.isGeneratingDeviceOrientationNotifications
        deviceInfo["deviceIsProximityMonitoringEnabled"] = UIDevice.current.isProximityMonitoringEnabled
        deviceInfo["deviceIsBatteryMonitoringEnabled"] = UIDevice.current.isBatteryMonitoringEnabled
        deviceInfo["deviceBatteryState"] = UIDevice.current.batteryState.rawValue
        deviceInfo["deviceBatteryLevel"] = UIDevice.current.batteryLevel
        deviceInfo["deviceOrientation"] = UIDevice.current.orientation.rawValue
        deviceInfo["deviceUserInterfaceIdiom"] = UIDevice.current.userInterfaceIdiom.rawValue
        deviceInfo["deviceIsGeneratingDeviceOrientationNotifications"] = UIDevice.current.isGeneratingDeviceOrientationNotifications
        deviceInfo["deviceIsProximityMonitoringEnabled"] = UIDevice.current.isProximityMonitoringEnabled
        deviceInfo["deviceIsBatteryMonitoringEnabled"] = UIDevice.current.isBatteryMonitoringEnabled
        deviceInfo["deviceBatteryState"] = UIDevice.current.batteryState.rawValue
        deviceInfo["deviceBatteryLevel"] = UIDevice.current.batteryLevel
        deviceInfo["deviceOrientation"] = UIDevice.current.orientation.rawValue
        deviceInfo["deviceUserInterfaceIdiom"] = UIDevice.current.userInterfaceIdiom.rawValue
        deviceInfo["deviceIsGeneratingDeviceOrientationNotifications"] = UIDevice.current.isGeneratingDeviceOrientationNotifications
        deviceInfo["deviceIsProximityMonitoringEnabled"] = UIDevice.current.isProximityMonitoringEnabled
        deviceInfo["deviceIsBatteryMonitoringEnabled"] = UIDevice.current.isBatteryMonitoringEnabled
        deviceInfo["deviceBatteryState"] = UIDevice.current.batteryState.rawValue
        deviceInfo["deviceBatteryLevel"] = UIDevice.current.batteryLevel
        

        return deviceInfo
    }
}

extension Dictionary {
    func jsonString(prettify: Bool = false) -> String? {
        guard JSONSerialization.isValidJSONObject(self) else { return nil }
        let options = (prettify == true) ? JSONSerialization.WritingOptions.prettyPrinted : JSONSerialization
            .WritingOptions()
        guard let jsonData = try? JSONSerialization.data(withJSONObject: self, options: options) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }
}

extension String {
    func toDic() -> [String: Any]? {
        guard let data = data(using: .utf8) else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any]
    }
}
