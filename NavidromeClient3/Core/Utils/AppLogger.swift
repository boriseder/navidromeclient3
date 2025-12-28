//
//  AppLogger.swift
//  NavidromeClient3
//
//  Swift 6: Fixed for global concurrency (Struct = Sendable)
//

import os
import Foundation

// MARK: - File Logging Actor
actor FileLogHandler {
    static let shared = FileLogHandler()
    
    private let logFileURL: URL
    
    private init() {
        let fm = FileManager.default
        let url = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppLogs.txt")
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil)
        }
        self.logFileURL = url
    }
    
    func write(_ text: String) {
        guard let data = (text + "\n").data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        }
    }
    
    nonisolated func getLogFilePath() -> URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppLogs.txt")
    }
}

enum AppLogger {
    // MARK: - Logger Wrapper (Struct)
    // Being a struct makes this implicitly Sendable because Logger is Sendable.
    // This allows static let properties to be accessed from any actor.
    struct LogWrapper: Sendable {
        let logger: Logger
        let category: String

        init(category: String) {
            self.category = category
            // Initialize Logger directly to avoid static dependency issues
            self.logger = Logger(subsystem: "at.amtabor.NavidromeClient", category: category)
        }

        func write(_ level: String, message: String, osLevel: OSLogType) {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(timestamp)] \(message)"

            Task {
                await FileLogHandler.shared.write(line)
            }
            
            logger.log(level: osLevel, "\(message, privacy: .public)")
        }

        func debug(_ msg: String) { write("🐞 DEBUG", message: msg, osLevel: .debug) }
        func info(_ msg: String)  { write("ℹ️ INFO", message: msg, osLevel: .info) }
        func warn(_ msg: String)  { write("⚠️ WARN", message: msg, osLevel: .default) }
        func error(_ msg: String) { write("❌ ERROR", message: msg, osLevel: .error) }
    }

    // MARK: - Categories
    static let general = LogWrapper(category: "General")
    static let ui      = LogWrapper(category: "UI")
    static let network = LogWrapper(category: "Network")
    static let audio   = LogWrapper(category: "Audio")
    static let cache   = LogWrapper(category: "Cache")

    static func logFilePath() -> URL {
        FileLogHandler.shared.getLogFilePath()
    }
}
