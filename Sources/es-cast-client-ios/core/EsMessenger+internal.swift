//
//  EsMessenger+internal.swift
//
//
//  Created by BM on 2023/10/16.
//

import Foundation
import UIKit

extension EsMessenger {
    func logDebugMessage(_ message: String) {
        if isDebugLogEnabled {
            print(message)
        }
    }

    func run() {
        LocalNetworkPermissionChecker() { [weak self] in
            self?.startUDPServer()
        } failure: { [weak self] error in
            self?.onNetworkPermissionCallback?(error)
        }
    }

    private func startUDPServer() {
        udp = try? UDP(port: 5000)
        try? udp?.run(callback: { [weak self] _, data, ip, prot in
            guard let self, let str = String(data: data, encoding: .utf8) else {
                return
            }
            server(didReceiveMessage: str, fromHost: ip, port: prot)
        })
    }

    /// 搜索设备
    func search() {
        LocalNetworkPermissionChecker { [weak self] in
            self?.performSearch()
        } failure: { [weak self] error in
            self?.onNetworkPermissionCallback?(error)
        }
    }

    private func performSearch() {
        udp?.startProxy()
        guard let ip = Utils.getIPAddress(), Utils.isValidIPAddress(ip) else {
            return
        }
        let ipComponents = ip.split(separator: ".").map { String($0) }
        let ipPrefix = ipComponents.prefix(3).joined(separator: ".")
        let ports = [5000, 5001]
        let hosts = (2 ... 254).map { "\(ipPrefix).\($0)" }

        for port in ports {
            for host in hosts {
                if host != ip {
                    DispatchQueue.global().async {
                        var msg: Message = .init(type: .search, data: nil)
                        msg.addConfig()
                        self.sendData(message: msg, toHost: host, port: port)
                    }
                }
            }
        }
    }

    func server(didReceiveMessage message: String, fromHost host: String, port: Int) {
        logDebugMessage("""
        Receive: \(host):\(port) Body: \(message)
        """)

        guard let jsonDictionary = message.toDic(),
              let typeInt = jsonDictionary["type"] as? Int,
              let type = MessageType(rawValue: typeInt)
        else {
            return
        }

        switch type {
        case .ping:
            let deviceKey = "\(host):\(port)"
            DispatchQueue.main.async { [weak self] in
                self?.handlePingResponse(from: deviceKey, success: true)
            }
        case .search:
            guard let dataDictionary = jsonDictionary["data"] as? [String: Any] else {
                return
            }
            let device = EsDevice(from: dataDictionary, ip: host, port: Int(port))
            DispatchQueue.main.async { [weak self] in
                self?.onFindDeviceCallback?(device)
                self?.notifyDelegates { $0.onFindDevice(device) }
            }
        default:
            guard let dataDictionary = jsonDictionary["data"] as? [String: Any] else {
                return
            }
            if let aciton = dataDictionary["action"] as? String, aciton == "update" {
                needCloseHost = UDP.setupAddress(ip: host, port: port)
            }
            let event = EsEvent(deviceIp: host, devicePort: Int(port), data: dataDictionary)
            DispatchQueue.main.async { [weak self] in
                self?.onReceiveEventCallback?(event)
                self?.notifyDelegates { $0.onReceiveEvent(event) }
            }
        }
    }

    /**
        发送数据到指定的主机和端口。
     */
    func sendData(message: Message, toHost host: String, port: Int) {
        guard let jsonStr = message.toDic().jsonString(),
              let jsonData = jsonStr.data(using: .utf8)
        else {
            return
        }

        // 如果是start_es，先开启代理, 延迟0.5发命令
        if let aciton = message.data?["action"] as? String, aciton == "start_es" {
            udp?.startProxy(host)
            logDebugMessage("""
            Send startProxy: \(host) {\(Date())}
            """)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                _ = self?.udp?.send(to: UDP.setupAddress(ip: host, port: port), with: jsonData)
                self?.logDebugMessage("""
                Send: \(host):\(port) Body: \(jsonStr) {\(Date())}
                """)
            }
        } else {
            _ = udp?.send(to: UDP.setupAddress(ip: host, port: port), with: jsonData)
            logDebugMessage("""
            Send: \(host):\(port) Body: \(jsonStr) {\(Date())}
            """)
        }
    }
}
