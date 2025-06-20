//
//  UDP.swift
//
//
//  Created by BM on 2023/10/18.
//

import Foundation
import Network
import Proxy
import UIKit

class UDP {
    enum Exception: Error {
        case unableToBind
        case unableToAllocate
    }

    private let listener: Int32
    private var live = true
    private var queue: DispatchQueue?
    private let lock = DispatchSemaphore(value: 1)
    private let stateLock = NSLock()
    private let bufferSize = 1024 * 4
    private static let pauseSleepMicroseconds: UInt32 = 10000
    private static let errorSleepMicroseconds: UInt32 = 10000
    private static let ipRangeStart = 2
    private static let ipRangeEnd = 254
    private let buffer: UnsafeMutableRawPointer

    init(port: Int = 0) throws {
        listener = socket(AF_INET, SOCK_DGRAM, 0)
        guard listener != -1 else {
            throw Exception.unableToBind
        }
        if port > 0 {
            var opt: Int32 = 1
            setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout.size(ofValue: opt)))
            let host = UDP.setupAddress(port: port)
            var address = UDP.convert(address: host)
            guard bind(listener, &address, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0 else {
                throw Exception.unableToBind
            }
            queue = DispatchQueue(label: "UDP-\(port)")
        } else {
            queue = nil
        }
        guard let buf = malloc(bufferSize) else {
            throw Exception.unableToAllocate
        }
        buffer = buf
    }

    func terminate() {
        stateLock.lock()
        defer { stateLock.unlock() }
        live = false
        isRunning = false
    }

    func listen() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard isRunning else { return }
        live = true
    }

    deinit {
        live = false
        isRunning = false
        free(self.buffer)
        close(listener)
    }

    static func setupAddress(ip: String = "0.0.0.0", port: Int) -> sockaddr_in {
        let ipAddr = inet_addr(ip)
        let lo = UInt16(port & 0x00ff) << 8
        let hi = UInt16(port & 0xff00) >> 8
        var host = sockaddr_in.init()
        host.sin_family = sa_family_t(AF_INET)
        host.sin_addr.s_addr = ipAddr
        host.sin_port = lo | hi
        return host
    }

    static func convert(address: sockaddr_in) -> sockaddr {
        var from = address
        var to = sockaddr()
        memcpy(&to, &from, MemoryLayout<sockaddr_in>.size)
        return to
    }

    static func cast(address: sockaddr) -> sockaddr_in {
        var from = address
        var to = sockaddr_in()
        memcpy(&to, &from, MemoryLayout<sockaddr_in>.size)
        return to
    }

    func send(to: sockaddr_in, with: Data) -> Int {
        var addr = sockaddr()
        var pto = to
        memcpy(&addr, &pto, MemoryLayout.size(ofValue: to))
        return send(to: addr, with: with)
    }

    func send(to: sockaddr, with: Data) -> Int {
        return UDP.send(by: listener, to: to, with: with)
    }

    public static func send(by: Int32, to: sockaddr, with: Data) -> Int {
        return with.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Int in
            var addr = to
            return sendto(by, buffer.baseAddress, with.count, 0, &addr, socklen_t(MemoryLayout.size(ofValue: to)))
        }
    }

    func startProxy(_ targetIp: String? = nil) {
        guard let cureentIp = Utils.getIPAddress(), Utils.isValidIPAddress(cureentIp) else {
            return
        }

        let ipComponents = cureentIp.split(separator: ".").map { String($0) }
        let ipPrefix = ipComponents.prefix(3).joined(separator: ".")

        let buffer = Proxy.makeStartProxy(cureentIp: cureentIp, targetIp)

        if let targetIp = targetIp {
            DispatchQueue.global().async { [weak self] in
                _ = self?.send(to: UDP.setupAddress(ip: targetIp, port: Proxy.Port), with: buffer)
            }
        } else {
            for i in Self.ipRangeStart ..< Self.ipRangeEnd {
                DispatchQueue.global().async { [weak self] in
                    _ = self?.send(to: UDP.setupAddress(ip: "\(ipPrefix).\(i)", port: Proxy.Port), with: buffer)
                }
            }
        }
    }

    private var isRunning = false
    private var callback: ((_ udp: UDP, _ data: Data, _ ip: String, _ prot: Int) -> Void)?
    
    public func run(callback: @escaping (_ udp: UDP, _ data: Data, _ ip: String, _ prot: Int) -> Void) throws {
        guard let q = queue else {
            throw Exception.unableToBind
        }
        
        self.callback = callback
        
        if isRunning {
            live = true
            return
        }
        
        live = true
        isRunning = true
        
        var flags = fcntl(listener, F_GETFL, 0)
        fcntl(listener, F_SETFL, flags | O_NONBLOCK)
        
        q.async {
            while true {
                self.stateLock.lock()
                let shouldRun = self.isRunning
                let isLive = self.live
                self.stateLock.unlock()
                
                if !shouldRun {
                    break
                }
                
                if !isLive {
                    usleep(Self.pauseSleepMicroseconds)
                    continue
                }
                
                self.lock.wait()
                defer { self.lock.signal() }
                
                var host = sockaddr()
                var size: UInt32 = socklen_t(MemoryLayout<sockaddr_storage>.size)
                let r = recvfrom(self.listener, self.buffer, self.bufferSize, 0, &host, &size)
                
                if r > 0 && r <= self.bufferSize && size <= MemoryLayout<sockaddr_in>.size {
                    let data = Data(bytes: self.buffer, count: r)
                    let address = UDP.cast(address: host)
                    let ip = String(cString: inet_ntoa(address.sin_addr))
                    let prot = Int(UInt16(bigEndian: address.sin_port))
                    self.callback?(self, data, ip, prot)
                } else if r < 0 {
                    let error = errno
                    if error != EAGAIN && error != EWOULDBLOCK {
                        break
                    }
                    usleep(Self.errorSleepMicroseconds)
                }
            }
        }
    }
}
