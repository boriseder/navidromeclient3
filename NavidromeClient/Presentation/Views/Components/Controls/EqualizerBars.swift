//
//  EqualizerBars.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Safe animation loop
//

import SwiftUI

struct EqualizerBars: View {
    let isActive: Bool
    let accentColor: Color
    
    @State private var animationState1: CGFloat = 0.4
    @State private var animationState2: CGFloat = 0.6
    @State private var animationState3: CGFloat = 0.5
    
    // Timer is replaced by a Task loop for cleaner concurrency
    
    var body: some View {
        HStack(spacing: 2) {
            bar(height: animationState1)
            bar(height: animationState2)
            bar(height: animationState3)
        }
        .frame(width: 18, height: 14)
        .task(id: isActive) {
            if isActive {
                await animate()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func bar(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(accentColor)
            .frame(width: 3)
            .frame(height: height * 14)
    }
    
    @MainActor
    private func animate() async {
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 0.3)) {
                animationState1 = CGFloat.random(in: 0.3...1.0)
                animationState2 = CGFloat.random(in: 0.3...1.0)
                animationState3 = CGFloat.random(in: 0.3...1.0)
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
    }
    
    private func stopAnimation() {
        withAnimation(.easeInOut(duration: 0.2)) {
            animationState1 = 0.3
            animationState2 = 0.3
            animationState3 = 0.3
        }
    }
}
