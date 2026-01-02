//
//  Debouncer.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Observable
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class Debouncer {
    @ObservationIgnored private var task: Task<Void, Never>?
    
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
