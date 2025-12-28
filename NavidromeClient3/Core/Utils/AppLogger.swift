//
//  AppLogger.swift
//  NavidromeClient3
//
//  Swift 6: Fixed - Explicit nonisolated init to satisfy global static requirements
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
    struct LogWrapper: Sendable {
        let logger: Logger
        let category: String

        // FIX: Explicitly mark init as 'nonisolated' so it can be used
        // in the static properties below without Actor isolation issues.
        nonisolated init(category: String) {
            self.category = category
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
    // These are now valid because LogWrapper.init is explicitly nonisolated
    nonisolated static let general = LogWrapper(category: "General")
    nonisolated static let ui      = LogWrapper(category: "UI")
    nonisolated static let network = LogWrapper(category: "Network")
    nonisolated static let audio   = LogWrapper(category: "Audio")
    nonisolated static let cache   = LogWrapper(category: "Cache")

    // FIX: Mark this as nonisolated too, so background services can ask for the path
    nonisolated static func logFilePath() -> URL {
        FileLogHandler.shared.getLogFilePath()
    }
}
