//
//  Debouncer.swift
//  NavidromeClient
//
//  Swift 6: UI Helper
//

import SwiftUI
import Combine
import Observation

@MainActor
@Observable
final class Debouncer {
    var input: String = "" {
        didSet {
            debouncedInput = input // Immediate update for binding
            // Cancel previous task
            searchTask?.cancel()
            // Schedule new task
            searchTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if !Task.isCancelled {
                    self.output = self.input
                }
            }
        }
    }
    
    var output: String = ""
    private var debouncedInput: String = ""
    private var searchTask: Task<Void, Never>?
    private let delay: TimeInterval
    
    init(delay: TimeInterval = 0.5) {
        self.delay = delay
    }
}
