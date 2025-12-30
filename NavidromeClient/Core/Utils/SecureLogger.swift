//
//  SecureLogger.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Marked final and Sendable
//  - os.Logger is thread-safe
//

import Foundation
import os.log

// MARK: - Secure Logger
final class SecureLogger: Sendable {
    static let shared = SecureLogger()
    
    // Logger struct is thread-safe
    private let logger = Logger(subsystem: "at.amtabor.NavidromeClient", category: "Network")
    private let authLogger = Logger(subsystem: "at.amtabor.NavidromeClient", category: "Authentication")
    
    private init() {}
    
    // MARK: - Public Logging Methods
    
    func logNetworkRequest(endpoint: String, method: String = "GET") {
        logger.info("🌐 Network request: \(method) \(endpoint)")
    }
    
    func logNetworkResponse(endpoint: String, statusCode: Int, duration: TimeInterval) {
        logger.info("📡 Response: \(endpoint) [\(statusCode)] in \(String(format: "%.2f", duration))s")
    }
    
    func logNetworkError(endpoint: String, error: Error) {
        logger.error("❌ Network error for \(endpoint): \(error.localizedDescription)")
    }
    
    func logAuthenticationAttempt(username: String, success: Bool) {
        // Anonymize username for logs
        let anonymizedUsername = anonymizeUsername(username)
        if success {
            authLogger.info(" Authentication successful for user: \(anonymizedUsername)")
        } else {
            authLogger.warning("🔒 Authentication failed for user: \(anonymizedUsername)")
        }
    }
    
    func logCacheOperation(_ operation: String, key: String, success: Bool) {
        let anonymizedKey = anonymizeKey(key)
        if success {
            logger.debug("💾 Cache \(operation): \(anonymizedKey)")
        } else {
            logger.warning("⚠️ Cache \(operation) failed: \(anonymizedKey)")
        }
    }
    
    func logDownloadProgress(songTitle: String, progress: Double) {
        let safeSongTitle = sanitizeForLogging(songTitle)
        logger.info("📥 Download progress: '\(safeSongTitle)' - \(Int(progress * 100))%")
    }
    
    func logPlayerEvent(_ event: String, songTitle: String? = nil) {
        if let title = songTitle {
            let safeTitle = sanitizeForLogging(title)
            logger.info("🎵 Player: \(event) - '\(safeTitle)'")
        } else {
            logger.info("🎵 Player: \(event)")
        }
    }
    
    func logSecurityEvent(_ event: String, severity: SecuritySeverity = .medium) {
        switch severity {
        case .low:
            authLogger.info("🔐 Security: \(event)")
        case .medium:
            authLogger.notice("🚨 Security: \(event)")
        case .high:
            authLogger.error("🔴 Security Alert: \(event)")
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func anonymizeUsername(_ username: String) -> String {
        guard username.count > 2 else { return "***" }
        return String(username.prefix(2)) + String(repeating: "*", count: username.count - 2)
    }
    
    private func anonymizeKey(_ key: String) -> String {
        // Only show first part of key
        guard key.count > 8 else { return "****" }
        return String(key.prefix(8)) + "..."
    }
    
    private func sanitizeForLogging(_ input: String) -> String {
        // Remove potentially harmful characters
        return input
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(100) // Limit length
            .description
    }
    
    enum SecuritySeverity: Sendable {
        case low, medium, high
    }
}

// MARK: - Enhanced Player Logging Extensions
extension PlayerViewModel {
    func logPlayEvent(song: Song) {
        SecureLogger.shared.logPlayerEvent("Starting playback", songTitle: song.title)
    }
    
    func logTogglePlayPause() {
        let action = isPlaying ? "Pausing" : "Resuming"
        SecureLogger.shared.logPlayerEvent(action, songTitle: currentSong?.title)
    }
    
    func logStop() {
        SecureLogger.shared.logPlayerEvent("Stopping playback", songTitle: currentSong?.title)
    }
}
