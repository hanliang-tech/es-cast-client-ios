//
//  EsDevice.swift
//
//
//  Created by BM on 2023/10/16.
//

import Foundation

/**
   表示 Messenger 发现的 EsDevice。

   - 注意: 该类提供了有关发现设备的信息。

   - 参数 id: 发现设备的唯一标识。
   - 参数 deviceName: 发现设备的名称。
   - 参数 deviceIp: 发现设备的IP地址。
   - 参数 devicePort: 发现设备的端口。
   - 参数 from: 发现起源的 APK 包名称。
   - 参数 findTime: 设备发现的时间戳。
   - 参数 version: 设备支持的协议版本。
 */
public struct EsDevice {
    /// 发现设备的唯一标识。
    public let id: String

    /// 发现设备的名称。
    public let deviceName: String

    /// 发现设备的IP地址。
    public let deviceIp: String

    /// 发现设备的端口。
    public let devicePort: Int

    /// 发现起源的 APK 包名称。
    public let from: String

    /// 设备发现的时间戳。
    public let findTime: TimeInterval

    /// 设备支持的协议版本。
    public let version: Int
}

extension EsDevice {
    init(from dic: [String: Any], ip: String, port: Int) {
        deviceIp = ip
        devicePort = port
        deviceName = dic["name"] as? String ?? ""
        from = dic["pkg"] as? String ?? ""
        version = dic["version"] as? Int ?? 0
        findTime = TimeInterval(Date().timeIntervalSince1970)
        id = dic["id"] as? String ?? UUID().uuidString
    }
}

// MARK: - EsCommand

enum MessageType: Int {
    case ping = 0
    case search
    case event
}

struct Message {
    let type: MessageType
    var data: [String: Any]?

    func toDic() -> [String: Any] {
        var dic: [String: Any] = [
            "type": type.rawValue,
        ]
        dic["data"] = data
        return dic
    }

    mutating func addConfig() {
        if data != nil {
            data!["device"] = ESConfig.device.data
        } else {
            data = ["device": ESConfig.device.data]
        }
    }
}

/// 回调事件
public struct EsEvent {
    public var deviceIp: String
    public var devicePort: Int
    public var data: [String: Any]
}
