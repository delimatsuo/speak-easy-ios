//
//  DeviceIdentity.swift
//  Mervyn Talks
//
//  Generates a stable, non-PII device hash used for abuse prevention and device binding.
//

import Foundation
import CryptoKit
import UIKit

final class DeviceIdentity {
    static let shared = DeviceIdentity()
    private init() {}

    private let saltKey = "com.mervyntalks.device.salt"

    /// Stable device hash derived from identifierForVendor and a random salt stored in Keychain.
    var deviceHash: String {
        let baseId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
        let salt = obtainOrCreateSalt()
        let combined = (baseId + ":" + salt).data(using: .utf8) ?? Data()
        let digest = SHA256.hash(data: combined)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func obtainOrCreateSalt() -> String {
        if let existing = try? KeychainManager.shared.retrieveAPIKey(forService: saltKey) {
            return existing
        }
        let newSalt = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        do { try KeychainManager.shared.storeAPIKey(newSalt, forService: saltKey) } catch {}
        return newSalt
    }
}


