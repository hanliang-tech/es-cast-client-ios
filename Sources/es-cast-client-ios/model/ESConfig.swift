//
//  ESConfig.swift
//
//
//  Created by BM on 2023/11/13.
//

import Foundation

public enum ESConfig {
    public static let device = Device()
}

public extension ESConfig {
    class Device {
        var data: [String: Any] = [:]

        @discardableResult
        public func idfa(_ idfa: String) -> ESConfig.Device {
            data["idfa"] = idfa
            return self
        }
        @discardableResult
        public func custom(_ key: String, value: String) -> ESConfig.Device {
            data[key] = value
            return self
        }
    }
}
