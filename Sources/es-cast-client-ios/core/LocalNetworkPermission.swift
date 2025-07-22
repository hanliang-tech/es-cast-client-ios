//
//  LocalNetworkPermission.swift
//
//
//  Created by BM on 2023/10/20.
//
import Foundation
import Network

class LocalNetworkAuthorization: NSObject {
    private var browser: NWBrowser?
    private var netService: NetService?
    private var completion: ((Bool) -> Void)?
    
    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        if #available(iOS 14, *) {
            requestLocalNetworkPermission(completion: completion)
        } else {
            completion(true)
        }
    }

    private func requestLocalNetworkPermission(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        let browser = NWBrowser(for: .bonjour(type: "_bonjour._tcp", domain: nil), using: parameters)
        browser.stateUpdateHandler = { newState in
            switch newState {
            case .failed(let error):
                print("Browser failed: \(error)")
            case .ready,
                 .cancelled:
                break
            case .waiting:
                self.completion?(false)
                self.tearDown()
            default:
                break
            }
        }
        self.browser = browser
        
        let netService = NetService(domain: "local.", type: "_es_local_network_check._tcp", name: "LocalNetworkAuthorization", port: 39393)
        netService.delegate = self
        self.netService = netService
        
        browser.start(queue: .main)
        netService.publish()
    }
    
    private func tearDown() {
        browser?.cancel()
        browser = nil
        netService?.stop()
        netService = nil
        completion = nil
    }
}

extension LocalNetworkAuthorization: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        completion?(true)
        tearDown()
    }
}
