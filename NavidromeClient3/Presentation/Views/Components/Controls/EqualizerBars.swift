//
//  EqualizerBars.swift
//  NavidromeClient
//
//  Swift 6: Fixed Initializer
//

import SwiftUI
import Combine

struct EqualizerBars: View {
    // FIX: Added public properties to match call site in QueueView
    var isActive: Bool = true
    var accentColor: Color = .blue
    
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(accentColor)
                    .frame(width: 3)
                    .frame(height: isAnimating ? CGFloat.random(in: 8...20) : 5)
                    .animation(
                        isActive ? .easeInOut(duration: 0.2).repeatForever().delay(Double(i) * 0.1) : .default,
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            if isActive { isAnimating = true }
        }
    }
}
