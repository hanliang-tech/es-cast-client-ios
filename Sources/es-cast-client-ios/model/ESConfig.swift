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
        public func oaid(_ id: String) -> ESConfig.Device {
            data["oaid"] = id
            return self
        }

        public func aaid(_ id: String) -> ESConfig.Device {
            data["aaid"] = id
            return self
        }
    }
}
