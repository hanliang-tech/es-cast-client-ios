//
//  EsMessenger.swift
//
//
//  Created by BM on 2023/10/16.
//

import Foundation
import Proxy
import UIKit

public protocol MessengerCallback: AnyObject {
    func onFindDevice(_ device: EsDevice)
    func onReceiveEvent(_ event: EsEvent)
}

/// 专门用于包裹 MessengerCallback 的弱引用包装器
class WeakMessengerCallbackWrapper {
    weak var value: MessengerCallback?
    init(value: MessengerCallback) { self.value = value }
}

public class EsMessenger: NSObject {
    /// 单例
    public static let shared: EsMessenger = .init()
    /// 是否显示日志
    public var isDebugLogEnabled: Bool = true

    public var config: ESConfig.Type = ESConfig.self
    /// 本机IP地址
    public var iPAddress: String? {
        Utils.getIPAddress()
    }

    /// 发现设备回调
    public var onFindDeviceCallback: ((EsDevice) -> Void)?
    /// 接收到事件回调
    public var onReceiveEventCallback: ((EsEvent) -> Void)?
    public var onNetworkPermissionCallback: ((Error?) -> Void)?

    /// 多播消息回调
    private var delegates: [WeakMessengerCallbackWrapper] = []

    /// 监听状态管理
    private let stateQueue = DispatchQueue(label: "EsMessenger.state", attributes: .concurrent)
    private var _isManualStopped: Bool = false
    private var _wasRunningBeforeBackground: Bool = false

    private var isManualStopped: Bool {
        get { stateQueue.sync { _isManualStopped } }
        set { stateQueue.async(flags: .barrier) { self._isManualStopped = newValue } }
    }

    private var wasRunningBeforeBackground: Bool {
        get { stateQueue.sync { _wasRunningBeforeBackground } }
        set { stateQueue.async(flags: .barrier) { self._wasRunningBeforeBackground = newValue } }
    }

    /// 添加回调对象
    public func addDelegate(_ delegate: MessengerCallback) {
        if !delegates.contains(where: { wrapper in
            guard let value = wrapper.value else { return false }
            return value === delegate
        }) {
            delegates.append(WeakMessengerCallbackWrapper(value: delegate))
        }
        cleanDelegates()
    }

    /// 移除回调对象
    public func removeDelegate(_ delegate: MessengerCallback) {
        delegates.removeAll { wrapper in
            guard let value = wrapper.value else { return true }
            return value === delegate
        }
        cleanDelegates()
    }

    /// 清理已释放的 delegate
    private func cleanDelegates() {
        var indicesToRemove: [Int] = []
        for (index, wrapper) in delegates.enumerated() {
            if wrapper.value == nil {
                indicesToRemove.append(index)
            }
        }
        for index in indicesToRemove.reversed() {
            delegates.remove(at: index)
        }
        logDebugMessage("清理已释放的代理，剩余代理数量: \(delegates.count)")
    }

    /// delegate通知
    func notifyDelegates(_ action: @escaping (MessengerCallback) -> Void) {
        let validDelegates = delegates.compactMap(\.value)
        for delegate in validDelegates {
            action(delegate)
        }
    }

    /// 处理ping响应
    func handlePingResponse(from deviceKey: String, success: Bool) {
        pingQueue.async(flags: .barrier) {
            let matchingKeys = self.pingCallbacks.keys.filter { $0.hasPrefix(deviceKey) }
            for key in matchingKeys {
                if let callback = self.pingCallbacks.removeValue(forKey: key) {
                    DispatchQueue.main.async {
                        callback(success)
                    }
                }
            }
        }
    }

    /// 兼容旧接口：setMessengerCallback 实际调用 addDelegate
    @available(*, deprecated, message: "请使用 addDelegate/removeDelegate 以支持多播代理")
    func setMessengerCallback(_ callback: MessengerCallback) {
        addDelegate(callback)
    }

    /// ping回调管理
    private var pingCallbacks: [String: (Bool) -> Void] = [:]
    private let pingQueue = DispatchQueue(label: "EsMessenger.ping", attributes: .concurrent)

    /// 需要关闭的Proxyu
    var needCloseHost: sockaddr_in?

    var udp: UDP?

    override init() {
        super.init()
        setupNotifications()
        run()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func applicationWillEnterForeground() {
        DispatchQueue.main.async {
            self.logDebugMessage("应用即将进入前台")
            if self.wasRunningBeforeBackground, !self.isManualStopped {
                self.logDebugMessage("恢复UDP监听")
                self.run()
            }
        }
    }

    @objc private func applicationDidEnterBackground() {
        DispatchQueue.main.async {
            self.logDebugMessage("应用进入后台")
            self.wasRunningBeforeBackground = self.udp != nil && !self.isManualStopped
            if self.wasRunningBeforeBackground {
                self.logDebugMessage("释放UDP资源")
                self.udp?.pause()
                self.udp = nil
            }
        }
    }
}

public extension EsMessenger {
    /* 
     注册消息回调。

     - Parameter callback: 实现 MessengerCallback 协议的回调对象
     */

    /**
     开始搜索设备。
     */
    func startDeviceSearch(failure: ((Error?) -> Void)? = nil) {
        LocalNetworkAuthorization.requestAuthorization { [weak self] authorized in
            if authorized {
                self?.search()
            } else {
                failure?(NSError(domain: "LocalNetworkAuthorization", code: 1, userInfo: [NSLocalizedDescriptionKey: "本地网络权限被拒绝"]))
            }
        }
    }

    /// 检查状态后checkDeviceOnline
    func checkDeviceOnlineAfterPermission(device: EsDevice,
                                          timeout: TimeInterval = 1,
                                          pingCallBack: ((Bool) -> Void)? = nil,
                                          failure: ((Error?) -> Void)? = nil)
    {
        LocalNetworkAuthorization.requestAuthorization { [weak self] authorized in
            if authorized {
                self?.checkDeviceOnline(device: device, timeout: timeout, pingCallBack: pingCallBack)
            } else {
                failure?(NSError(domain: "LocalNetworkAuthorization", code: 1, userInfo: [NSLocalizedDescriptionKey: "Local network permission denied."]))
            }
        }
    }

    /**
     检测设备是否在线。

     - Parameter device: EsDevice 对象表示的设备
     - Parameter timeout: 超时时间 默认1秒
     - Parameter pingCallBack: ping 回调
     */
    func checkDeviceOnline(device: EsDevice, timeout: TimeInterval = 1, pingCallBack: ((Bool) -> Void)? = nil) {
        let callbackId = "\(device.deviceIp):\(device.devicePort):\(Date().timeIntervalSince1970)"

        if let callback = pingCallBack {
            pingQueue.async(flags: .barrier) {
                self.pingCallbacks[callbackId] = callback
            }
        }

        var msg: Message = .init(type: .ping, data: nil)
        msg.addConfig()
        sendData(message: msg,
                 toHost: device.deviceIp,
                 port: device.devicePort)

        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.pingQueue.async(flags: .barrier) {
                if let callback = self?.pingCallbacks.removeValue(forKey: callbackId) {
                    DispatchQueue.main.async {
                        callback(false)
                    }
                }
            }
        }
    }

    /**
     检测设备是否在线。

     - Parameter device: EsDevice 对象表示的设备
     - Parameter timeout: 超时时间 默认1秒
     - Returns: 是否在线 (Async)
      */
    @available(iOS 13.0.0, *)
    func checkDeviceOnline(device: EsDevice, timeout: TimeInterval) async -> Bool {
        let result = await withCheckedContinuation { c in
            checkDeviceOnline(device: device, timeout: timeout) { result in
                c.resume(returning: result)
            }
        }
        return result
    }

    /**
     发送命令。

     - Parameter device: EsDevice 对象表示的设备
     - Parameter command: EsCommand 对象表示的命令
     */
    func sendDeviceCommand(device: EsDevice, action: EsAction) {
        var msg: Message = .init(type: .event, data: action.data)
        msg.addConfig()
        sendData(message: msg,
                 toHost: device.deviceIp,
                 port: device.devicePort)
    }

    /**
     停止监听
     */
    func stop() {
        isManualStopped = true
        udp?.pause()
        udp = nil

        if let host = needCloseHost {
            _ = udp?.send(to: host, with: Proxy.makeStop())
        }
    }

    /**
     继续监听
     */
    func resume() {
        isManualStopped = false
        if udp == nil {
            run()
        } else {
            udp?.resume()
        }
    }
}
