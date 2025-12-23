//
//  Debouncer.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//
import Foundation
import SwiftUI

@MainActor
final class Debouncer: ObservableObject {
    private var timer: Timer?
    
    func debounce(interval: TimeInterval = 0.5, action: @escaping () -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            action()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
