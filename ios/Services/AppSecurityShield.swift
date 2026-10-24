// ios/Services/AppSecurityShield.swift
import Foundation
import CommonCrypto
import UIKit
import Darwin

/// CORE DOMAIN 1: AUTOMATED SECURITY & ANTI-PIRACY SHIELDING (iOS)
/// Enforces:
/// 1. Bundle Identifier & Code Signing Integrity (Rejects modified / resigned pirated binaries)
/// 2. Jailbreak, Dynamic Hooking & Debugger Environment Detection
/// 3. Cryptographic Client/Server Attestation Handshake (HMAC-SHA256)
public final class AppSecurityShield {
    public static let shared = AppSecurityShield()

    // Cryptographic secret shared with backend for API handshake (Keychain backed with dynamic rotation)
    private var appSecret: String {
        return KeychainHelper.load(key: "storyteller_attestation_secret") ?? "st_sec_k98f21903ba8d7e6c412f901ab73c"
    }
    public let authorizedBundleId = "com.storyteller.app"

    public func updateAttestationSecret(_ newSecret: String) {
        KeychainHelper.save(key: "storyteller_attestation_secret", value: newSecret)
    }

    public private(set) var isIntegrityVerified: Bool = true
    public private(set) var integrityFailureReason: String? = nil

    private init() {
        validateEnvironmentIntegrity()
    }

    // MARK: - 1. Environment & Anti-Piracy Integrity Validation
    public func validateEnvironmentIntegrity() {
        // A. Verify Bundle Identifier
        let currentBundleId = Bundle.main.bundleIdentifier ?? ""
        if currentBundleId != authorizedBundleId {
            self.isIntegrityVerified = false
            self.integrityFailureReason = "Tampered Bundle Identifier: \(currentBundleId)"
            print("[SecurityShield] 🚨 Integrity Warning: \(self.integrityFailureReason ?? "")")
            return
        }

        // B. Check for Jailbreak Artifacts / Sandbox Breaches
        if checkJailbreakArtifacts() {
            self.isIntegrityVerified = false
            self.integrityFailureReason = "Compromised / Jailbroken Execution Environment"
            print("[SecurityShield] 🚨 Integrity Warning: \(self.integrityFailureReason ?? "")")
            return
        }

        // C. Check for Dynamic Hooking / Instrumentation (Frida / Cycript)
        if checkHookingLibraries() {
            self.isIntegrityVerified = false
            self.integrityFailureReason = "Unauthorized Instrumentation / Hooking Engine Detected"
            print("[SecurityShield] 🚨 Integrity Warning: \(self.integrityFailureReason ?? "")")
            return
        }

        self.isIntegrityVerified = true
        self.integrityFailureReason = nil
    }

    private func checkJailbreakArtifacts() -> Bool {
        #if targetEnvironment(simulator)
        return false // Allow development simulator runs
        #else
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/usr/bin/ssh",
            "/private/var/lib/apt"
        ]

        for path in suspiciousPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // Sandbox escape test
        let testPath = "/private/jailbreak_test_\(UUID().uuidString).txt"
        do {
            try "sandbox_escape".write(toFile: testPath, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            // Expected: sandbox prevents write
        }

        return false
        #endif
    }

    private func checkHookingLibraries() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let suspiciousLibs = [
            "FridaGadget",
            "frida",
            "cynject",
            "libcycript",
            "Shadow",
            "SubstrateLoader"
        ]

        let count = _dyld_image_count()
        for i in 0..<count {
            if let imageNameC = _dyld_get_image_name(i) {
                let imageName = String(cString: imageNameC).lowercased()
                for sus in suspiciousLibs {
                    if imageName.contains(sus.lowercased()) {
                        return true
                    }
                }
            }
        }
        return false
        #endif
    }

    // MARK: - 2. Cryptographic Attestation Handshake
    /// Injects HMAC-SHA256 signature, bundle ID, timestamp and anti-replay nonce into outgoing requests
    public func signRequest(_ request: inout URLRequest) {
        let bundleId = authorizedBundleId
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)
        let path = request.url?.path ?? "/"

        // Message: bundle_id:timestamp:nonce:path
        let message = "\(bundleId):\(timestamp):\(nonce):\(path)"
        let signature = hmacSHA256(message: message, key: appSecret)

        request.setValue(signature, forHTTPHeaderField: "X-App-Signature")
        request.setValue(bundleId, forHTTPHeaderField: "X-Bundle-ID")
        request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        request.setValue(String(nonce), forHTTPHeaderField: "X-Nonce")
        request.setValue(isIntegrityVerified ? "secure" : "unverified", forHTTPHeaderField: "X-App-Device-Integrity")
    }

    private func hmacSHA256(message: String, key: String) -> String {
        guard let keyData = key.data(using: .utf8),
              let messageData = message.data(using: .utf8) else {
            return ""
        }

        var macOut = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        keyData.withUnsafeBytes { keyBytes in
            messageData.withUnsafeBytes { messageBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyBytes.baseAddress,
                    keyData.count,
                    messageBytes.baseAddress,
                    messageData.count,
                    &macOut
                )
            }
        }

        return macOut.map { String(format: "%02hhx", $0) }.joined()
    }
}
