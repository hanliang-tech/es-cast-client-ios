//
//  EsMessenger.swift
//
//
//  Created by BM on 2023/10/16.
//

import Foundation
import Proxy

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

    /// 多播消息回调
    var delegates: [WeakMessengerCallbackWrapper] = []

    /// 添加回调对象
    public func addDelegate(_ delegate: MessengerCallback) {
        // 避免重复添加
        if !delegates.contains(where: { $0.value === delegate }) {
            delegates.append(WeakMessengerCallbackWrapper(value: delegate))
        }
        cleanDelegates()
    }

    /// 移除回调对象
    public func removeDelegate(_ delegate: MessengerCallback) {
        delegates.removeAll { $0.value === delegate }
        cleanDelegates()
    }

    /// 清理已释放的 delegate
    private func cleanDelegates() {
        delegates = delegates.filter { $0.value != nil }
    }

    /// 兼容旧接口：setMessengerCallback 实际调用 addDelegate
    @available(*, deprecated, message: "请使用 addDelegate/removeDelegate 以支持多播代理")
    func setMessengerCallback(_ callback: MessengerCallback) {
        addDelegate(callback)
    }


    /// ping回调
    var pingCallBack: ((Bool) -> Void)?

    /// 需要关闭的Proxyu
    var needCloseHost: sockaddr_in?

    var udp: UDP?

    override init() {
        super.init()
        run()
    }
}

public extension EsMessenger {
    /**
     注册消息回调。

     - Parameter callback: 实现 MessengerCallback 协议的回调对象
     */


    /**
     开始搜索设备。
     */
    func startDeviceSearch() {
        search()
    }

    /**
     检测设备是否在线。

     - Parameter device: EsDevice 对象表示的设备
     - Parameter timeout: 超时时间 默认1秒
     - Parameter pingCallBack: ping 回调
     */
    func checkDeviceOnline(device: EsDevice, timeout: TimeInterval = 1, pingCallBack: ((Bool) -> Void)? = nil) {
        self.pingCallBack = pingCallBack
        var msg: Message = .init(type: .ping, data: nil)
        msg.addConfig()
        sendData(message: msg,
                 toHost: device.deviceIp,
                 port: device.devicePort)
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.pingCallBack?(false)
            self?.pingCallBack = nil
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
        udp?.terminate()
        
        if let host = needCloseHost {
            _ = udp?.send(to: host, with: Proxy.makeStop())
        }
    }

    /**
     继续监听
     */
    func resume() {
        udp?.listen()
    }
}
