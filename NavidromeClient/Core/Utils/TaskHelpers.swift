//
//  TaskHelpers.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Generic Extensions are safe
//

import Foundation

extension Task where Failure == Never {
    /// Safely cancels and awaits task completion
    func cancelAndWait() async {
        self.cancel()
        _ = await self.value
    }
}

extension Task where Failure == Error {
    /// Safely cancels and awaits task completion, ignoring errors
    func cancelAndWaitIgnoringErrors() async {
        self.cancel()
        _ = try? await self.value
    }
}

/// Helper to check cancellation with logging
func checkCancellation(context: String) throws {
    if Task.isCancelled {
        AppLogger.general.info("⚠️ Task cancelled: \(context)")
        throw CancellationError()
    }
}
