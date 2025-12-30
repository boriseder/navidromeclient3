//
//  AppLogger.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Thread-safe file writing using Serial Queue
//  - Sendable conformance for LogWrapper
//

import os
import Foundation

enum AppLogger {
    private static let subsystem = "at.amtabor.NavidromeClient"

    // MARK: - Logger Wrapper
    // Swift 6: Marked @unchecked Sendable because Logger is thread-safe and category is immutable.
    final class LogWrapper: @unchecked Sendable {
        let logger: Logger
        let category: String

        init(logger: Logger, category: String) {
            self.logger = logger
            self.category = category
        }

        func write(_ level: String, message: String, osLevel: OSLogType) {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(timestamp)] \(message)"

            // Non-blocking file write
            AppLogger.writeToFile(line)
            
            // System Console Log
            logger.log(level: osLevel, "\(line, privacy: .public)")
        }

        func debug(_ msg: String) { write("🐞 DEBUG", message: msg, osLevel: .debug) }
        func info(_ msg: String)  { write("ℹ️ INFO", message: msg, osLevel: .info) }
        func warn(_ msg: String)  { write("⚠️ WARN", message: msg, osLevel: .default) }
        func error(_ msg: String) { write("❌ ERROR", message: msg, osLevel: .error) }
    }

    // MARK: - Categories
    static let general = LogWrapper(logger: Logger(subsystem: subsystem, category: "General"), category: "General")
    static let ui      = LogWrapper(logger: Logger(subsystem: subsystem, category: "UI"), category: "UI")
    static let network = LogWrapper(logger: Logger(subsystem: subsystem, category: "Network"), category: "Network")
    static let audio   = LogWrapper(logger: Logger(subsystem: subsystem, category: "Audio"), category: "Audio")
    static let cache   = LogWrapper(logger: Logger(subsystem: subsystem, category: "Cache"), category: "Cache")

    // MARK: - File Logging
    
    // Serial queue for thread-safe file writing
    private static let fileQueue = DispatchQueue(label: "at.amtabor.NavidromeClient.LogFileQueue", qos: .utility)

    private static let logFileURL: URL = {
        let fm = FileManager.default
        let url = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppLogs.txt")
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil)
        }
        return url
    }()

    static func writeToFile(_ text: String) {
        // Offload to background serial queue to prevent blocking caller
        fileQueue.async {
            guard let data = (text + "\n").data(using: .utf8) else { return }
            
            // Use FileHandle in a do-catch block for safety
            do {
                let handle = try FileHandle(forWritingTo: logFileURL)
                defer { try? handle.close() }
                
                if #available(iOS 13.4, *) {
                    try handle.seekToEnd()
                } else {
                    handle.seekToEndOfFile()
                }
                handle.write(data)
            } catch {
                // Fail silently if logging fails to prevent loops
                print("Failed to write to log file: \(error)")
            }
        }
    }

    static func logFilePath() -> URL { logFileURL }
}
