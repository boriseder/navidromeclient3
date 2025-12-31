//
//  Debouncer.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Replaced unsafe Timer with Task
//  - Removed deinit to fix isolation errors
//

import Foundation
import SwiftUI

@MainActor
final class Debouncer: ObservableObject {
    private var task: Task<Void, Never>?
    
    func debounce(interval: TimeInterval = 0.5, action: @escaping @MainActor () -> Void) {
        // Cancel the previous task if it's still running
        task?.cancel()
        
        // Start a new task
        task = Task {
            do {
                // Convert seconds to nanoseconds
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                
                // Only execute if not cancelled
                if !Task.isCancelled {
                    action()
                }
            } catch {
                // Task cancelled, ignore
            }
        }
    }
}
