//
//  LocalNetworkPermission.swift
//
//
//  Created by BM on 2023/10/20.
//

import Foundation
import Network
import NetworkExtension
import UIKit

class LocalNetworkPermissionChecker {
    private var host: String
    private var port: UInt16
    private var checkPermissionStatus: DispatchWorkItem?
    
    private lazy var detectDeclineTimer: Timer? = Timer.scheduledTimer(
        withTimeInterval: .zero,
        repeats: false,
        block: { [weak self] _ in
            guard let checkPermissionStatus = self?.checkPermissionStatus else { return }
            DispatchQueue.main.asyncAfter(deadline: .now(), execute: checkPermissionStatus)
        })
    
    @discardableResult
    init(host: String, port: UInt16, granted: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        self.host = host
        self.port = port
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationIsInBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationIsInForeground),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        
        actionRequestNetworkPermissions(granted: granted, failure: failure)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func actionRequestNetworkPermissions(granted: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        guard let port = NWEndpoint.Port(rawValue: port) else { return }
        
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .udp)
        connection.start(queue: .main)
        
        checkPermissionStatus = DispatchWorkItem(block: { [weak self] in
            if connection.state == .ready {
                self?.detectDeclineTimer?.invalidate()
                granted()
            } else {
                failure(nil)
            }
        })
        
        detectDeclineTimer?.fireDate = Date() + 1
    }
    
    @objc private func applicationIsInBackground() {
        detectDeclineTimer?.invalidate()
    }
    
    @objc private func applicationIsInForeground() {
        guard let checkPermissionStatus = checkPermissionStatus else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: checkPermissionStatus)
    }
}
