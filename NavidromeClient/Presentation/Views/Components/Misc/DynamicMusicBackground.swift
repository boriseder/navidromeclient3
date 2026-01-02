//
//  DynamicMusicBackground.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency & @Observable
//

import SwiftUI

struct DynamicMusicBackground: View {
    @Environment(ThemeManager.self) var theme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.accent.opacity(0.05),
                    theme.accent.opacity(0.08),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    theme.accent.opacity(0.2),
                    .clear
                ],
                center: UnitPoint(x: 0.4, y: 0.3),
                startRadius: 100,
                endRadius: 500
            )
            .blendMode(.screen)
            .ignoresSafeArea()

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.015),
                            .clear,
                            .black.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
    }
}
