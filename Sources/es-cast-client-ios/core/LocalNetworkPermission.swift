//
//  LocalNetworkPermission.swift
//
//
//  Created by BM on 2023/10/20.
//
import Foundation
import Network

private let type = "_es_local_network_check._tcp"

class LocalNetworkAuthorization: NSObject {
  @objc static func requestAuthorization(completion: @escaping (Bool) -> Void) {
    Task {
      do {
        let result = try await requestLocalNetworkAuthorization()
        completion(result)
      } catch {
        completion(false)
      }
    }
  }
}

@discardableResult
func requestLocalNetworkAuthorization() async throws -> Bool {
  let queue = DispatchQueue(label: "es-cast-client-ios.localNetworkAuthCheck")

  let listener = try NWListener(using: NWParameters(tls: .none, tcp: NWProtocolTCP.Options()))
  listener.service = NWListener.Service(name: UUID().uuidString, type: type)
  listener.newConnectionHandler = { _ in } // Must be set or else the listener will error with POSIX error 22

  let parameters = NWParameters()
  parameters.includePeerToPeer = true
  let browser = NWBrowser(for: .bonjour(type: type, domain: nil), using: parameters)
    
  return try await withTaskCancellationHandler {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
      class LocalState {
        var didResume = false
      }
      let local = LocalState()
      @Sendable func resume(with result: Result<Bool, Error>) {
        if local.didResume {
          return
        }
        local.didResume = true

        listener.stateUpdateHandler = { _ in }
        browser.stateUpdateHandler = { _ in }
        browser.browseResultsChangedHandler = { _, _ in }
        listener.cancel()
        browser.cancel()

        continuation.resume(with: result)
      }

      if Task.isCancelled {
        resume(with: .failure(CancellationError()))
        return
      }

      listener.stateUpdateHandler = { newState in
        switch newState {
        case .setup:
          return
        case .ready:
          return
        case .cancelled:
          resume(with: .failure(CancellationError()))
        case .failed(let error):
          resume(with: .failure(error))
        case .waiting(let error):
          resume(with: .failure(error))
        @unknown default:
          return
        }
      }
      listener.start(queue: queue)

      browser.stateUpdateHandler = { newState in
        switch newState {
        case .setup:
          return
        case .ready:
          return
        case .cancelled:
          resume(with: .failure(CancellationError()))
        case .failed(let error):
          resume(with: .failure(error))
        case let .waiting(error):
          switch error {
          case .dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied)):
            resume(with: .success(false))
          default:
            resume(with: .failure(error))
          }
        @unknown default:
          return
        }
      }

      browser.browseResultsChangedHandler = { results, _ in
        if results.isEmpty {
          return
        }
        resume(with: .success(true))
      }
      browser.start(queue: queue)

      if Task.isCancelled {
        resume(with: .failure(CancellationError()))
        return
      }
    }
  } onCancel: {
    listener.cancel()
    browser.cancel()
  }
}
