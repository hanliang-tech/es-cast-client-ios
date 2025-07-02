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
    private var connection: NWConnection?
    private var listener: NWListener?
    private var hasCalledCompletion = false
    private var grantedCallback: (() -> Void)?
    private var failureCallback: ((Error?) -> Void)?
    
    @discardableResult
    init(granted: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        self.grantedCallback = granted
        self.failureCallback = failure
        
        startNetworkPermissionCheck()
    }
    
    deinit {
        connection?.cancel()
        listener?.cancel()
    }
    
    private func startNetworkPermissionCheck() {
        listener = try? NWListener(using: .tcp)
        listener?.stateUpdateHandler = { [weak self] state in
            guard let self = self, !self.hasCalledCompletion else { return }
            
            switch state {
            case .ready:
                self.hasCalledCompletion = true
                self.grantedCallback?()
                self.listener?.cancel()
                self.clearCallbacks()
            case .failed(let error):
                self.hasCalledCompletion = true
                self.failureCallback?(error)
                self.listener?.cancel()
                self.clearCallbacks()
            case .cancelled:
                break
            default:
                break
            }
        }
        listener?.start(queue: .main)
    }
    
    private func clearCallbacks() {
        grantedCallback = nil
        failureCallback = nil
    }
}
