//
//  EqualizerBars.swift
//  NavidromeClient
//
//  Created by Boris Eder on 22.09.25.
//
import SwiftUI

struct EqualizerBars: View {
    let isActive: Bool
    let accentColor: Color
    
    @State private var barScales: [CGFloat] = [0.3, 0.5, 0.8]
    
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(accentColor)
                    .frame(width: 3, height: maxHeight)
                    .scaleEffect(y: barScales[index], anchor: .bottom)
                    .animation(
                        .interpolatingSpring(stiffness: 100, damping: 12)
                        .delay(Double(index) * 0.1),
                        value: barScales[index]
                    )
            }
        }
        .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
        .background(
            Circle()
                .fill(accentColor.opacity(0.15))
                .overlay(
                    Circle()
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
        .onReceive(timer) { _ in
            updateBars()
        }
        .onAppear {
            if isActive { updateBars() }
        }
    }
    
    private var maxHeight: CGFloat { 14 }
    
    private func updateBars() {
        guard isActive else {
            barScales = [0.3, 0.3, 0.3]
            return
        }
        
        barScales = (0..<3).map { _ in
            CGFloat.random(in: 0.2...1.0)
        }
    }
}
