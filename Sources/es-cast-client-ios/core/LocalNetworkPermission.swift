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
    private var connection: NWConnection?
    private var hasCalledCompletion = false
    private var grantedCallback: (() -> Void)?
    private var failureCallback: ((Error?) -> Void)?
    
    @discardableResult
    init(host: String, port: UInt16, granted: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        self.host = host
        self.port = port
        self.grantedCallback = granted
        self.failureCallback = failure
        
        startNetworkPermissionCheck()
    }
    
    deinit {
        connection?.cancel()
    }
    
    private func startNetworkPermissionCheck() {
        guard let port = NWEndpoint.Port(rawValue: port) else { return }
        
        connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .udp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self, !self.hasCalledCompletion else { return }
            
            switch state {
            case .ready:
                self.hasCalledCompletion = true
                self.grantedCallback?()
                self.connection?.cancel()
                self.clearCallbacks()
            case .failed(let error):
                self.hasCalledCompletion = true
                self.failureCallback?(error)
                self.connection?.cancel()
                self.clearCallbacks()
            case .cancelled:
                break
            default:
                break
            }
        }
        
        connection?.start(queue: .main)
    }
    
    private func clearCallbacks() {
        grantedCallback = nil
        failureCallback = nil
    }
}
