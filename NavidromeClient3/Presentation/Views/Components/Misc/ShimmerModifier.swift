//
//  ShimmerModifier.swift
//  NavidromeClient3
//
//  Created by Boris Eder on 30.12.25.
//


//
//  ShimmerEffect.swift
//  NavidromeClient3
//
//  Swift 6: Reusable Shimmer Modifier
//

import SwiftUI

extension View {
    func shimmering(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}

struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = -0.5
    
    func body(content: Content) -> some View {
        if !active {
            content
        } else {
            content
                .overlay(
                    GeometryReader { geo in
                        Color.white.opacity(0.4)
                            .mask(
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: .clear, location: 0.3),
                                                .init(color: .white, location: 0.5),
                                                .init(color: .clear, location: 0.7)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .scaleEffect(3)
                                    .rotationEffect(.degrees(30))
                                    .offset(x: phase * geo.size.width * 3)
                            )
                    }
                )
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1.5
                    }
                }
                .mask(content)
        }
    }
}