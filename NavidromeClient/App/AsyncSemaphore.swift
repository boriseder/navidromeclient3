//
//  AsyncSemaphore.swift
//  NavidromeClient
//
//  Created by Boris Eder on 30.12.25.
//


//
//  AsyncSemaphore.swift
//  NavidromeClient
//
//  NEW: Thread-safe semaphore for controlling concurrency
//  Required for CoverArtManager
//

import Foundation

actor AsyncSemaphore {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.permits = value
    }

    func wait() async {
        permits -= 1
        if permits < 0 {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }

    func signal() {
        permits += 1
        if !waiters.isEmpty {
            let continuation = waiters.removeFirst()
            continuation.resume()
        }
    }
}