//
//  Debouncer.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Strictly MainActor
//

import Foundation
import SwiftUI

@MainActor
final class Debouncer: ObservableObject {
    private var timer: Timer?
    
    func debounce(interval: TimeInterval = 0.5, action: @escaping @MainActor () -> Void) {
        timer?.invalidate()
        // Scheduled on the current RunLoop (Main) because class is @MainActor
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                action()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
