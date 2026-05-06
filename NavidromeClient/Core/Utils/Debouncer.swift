//
//  Debouncer.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - FIXED Bug 21: Removed @Observable to prevent SwiftUI lifecycle destruction
//  - Modern Concurrency (Task.sleep)
//

import Foundation

@MainActor
final class Debouncer {
    private var task: Task<Void, Never>?
    
    func debounce(interval: TimeInterval = 0.5, action: @escaping @MainActor () -> Void) {
        task?.cancel()
        
        task = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if !Task.isCancelled {
                    action()
                }
            } catch {
                // Cancelled
            }
        }
    }
}
