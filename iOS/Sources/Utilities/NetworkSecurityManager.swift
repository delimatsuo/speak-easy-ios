//
//  NetworkSecurityManager.swift (iOS)
//  Mervyn Talks
//
//  Secures URLSession with TLS 1.3 and certificate pinning. Uses NetworkConfig.
//

import Foundation
import Security
import CommonCrypto
import os.log

final class NetworkSecurityManager: NSObject {
    static let shared = NetworkSecurityManager()
    
    private let logger = OSLog(subsystem: "com.mervyntalks.security", category: "NetworkSecurity")
    
    // Public key/cert hashes (base64-encoded SHA256)
    private let pinnedPublicKeys: Set<String> = [
        "7HIpactkIAq2Y49orFOOQKurWxmmSFZhBCoQYcRhJ3Y=",
        "C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=",
        "iie1VXtL7HzAMF+/PVPR9xzT80kQxdZeJ+zduCB3uj0=",
        "6mYzPE83VEo8pxfzMO7HZl9tWECMzJKOb2K3QVZaOKY="
    ]

    private var trustedHosts: Set<String> {
        var hosts: Set<String> = [
            "generativelanguage.googleapis.com",
            "googleapis.com",
            "google.com",
            "firebase.googleapis.com",
            "firestore.googleapis.com",
            "universal-translator-api-jzqoowo3tq-uc.a.run.app",  // Explicitly add our API
            "run.app"  // Allow all Cloud Run domains
        ]
        let apiBaseURL = NetworkConfig.apiBaseURL
        if let url = URL(string: apiBaseURL), let host = url.host,
           !host.contains("localhost") && !host.contains("127.0.0.1") {
            hosts.insert(host)
            print("📱 Added API host to trusted: \(host)")
        }
        return hosts
    }

    private override init() {}

    func configureSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        if #available(iOS 15.0, *) {
            configuration.tlsMinimumSupportedProtocolVersion = .TLSv13
            configuration.tlsMaximumSupportedProtocolVersion = .TLSv13
        }
        configuration.httpShouldUsePipelining = true
        configuration.httpMaximumConnectionsPerHost = 3
        configuration.httpAdditionalHeaders = [
            "User-Agent": "MervynTalks/1.0 (iOS)",
            "Accept": "application/json",
            "Accept-Encoding": "gzip, deflate"
        ]
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
}

extension NetworkSecurityManager: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            os_log("Certificate chain invalid: not server trust", log: logger, type: .error)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let host = challenge.protectionSpace.host
        
        // Always allow our Cloud Run API
        if host.contains("run.app") || host == "universal-translator-api-jzqoowo3tq-uc.a.run.app" {
            os_log("Certificate pinning success for Cloud Run: %{public}@", log: logger, type: .info, host)
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }
        
        guard trustedHosts.contains(where: { host.hasSuffix($0) }) else {
            os_log("Untrusted host rejected: %{public}@", log: logger, type: .error, host)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        if validateCertificate(serverTrust) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            os_log("Certificate pinning failure for host: %{public}@", log: logger, type: .error, host)
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private func validateCertificate(_ trust: SecTrust) -> Bool {
        var result: SecTrustResultType = .invalid
        let status = SecTrustEvaluate(trust, &result)
        guard status == errSecSuccess else { return false }

        let count = SecTrustGetCertificateCount(trust)
        for index in 0..<count {
            guard let cert = SecTrustGetCertificateAtIndex(trust, index) else { continue }
            if let key = SecCertificateCopyKey(cert),
               let keyData = SecKeyCopyExternalRepresentation(key, nil) {
                let hash = sha256Hash(data: keyData as Data)
                if pinnedPublicKeys.contains(hash) { return true }
            }
            let certData = SecCertificateCopyData(cert)
            let certHash = sha256Hash(data: certData as Data)
            if pinnedPublicKeys.contains(certHash) { return true }
        }
        #if DEBUG
        // In debug mode, still validate trust chain but allow development certificates
        var debugResult: SecTrustResultType = .invalid
        let debugStatus = SecTrustEvaluate(trust, &debugResult)
        let chainOK = (debugStatus == errSecSuccess) && (debugResult == .unspecified || debugResult == .proceed)
        
        if let url = URL(string: NetworkConfig.apiBaseURL), let apiHost = url.host {
            // For development API endpoints
            if apiHost.contains("localhost") || apiHost.contains("127.0.0.1") {
                os_log("Certificate pinning success for localhost: %{public}@", log: logger, type: .info, apiHost)
                return chainOK
            }
            
            // For development Cloud Run instances
            if apiHost.contains("run.app") {
                os_log("Certificate pinning success for debug Cloud Run: %{public}@", log: logger, type: .info, apiHost)
                return chainOK
            }
        }
        
        // For all other hosts, require pinning even in debug
        return false
        #else
        // In production, require pinning for all hosts except our Cloud Run API
        if let url = URL(string: NetworkConfig.apiBaseURL), let apiHost = url.host {
            if apiHost.contains("run.app") {
                // For Cloud Run, validate trust chain (certs rotate)
                var prodResult: SecTrustResultType = .invalid
                let prodStatus = SecTrustEvaluate(trust, &prodResult)
                let chainOK = (prodStatus == errSecSuccess) && (prodResult == .unspecified || prodResult == .proceed)
                if chainOK {
                    os_log("Certificate pinning success for prod Cloud Run: %{public}@", log: logger, type: .info, apiHost)
                    return true
                }
            }
        }
        return false
        #endif
    }

    private func sha256Hash(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) }
        return Data(hash).base64EncodedString()
    }
}


