//
//  HeartButton.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Tasks are safely isolated
//

import SwiftUI

struct HeartButton: View {
    let song: Song
    let size: HeartButtonSize
    let style: HeartButtonStyle
    let unfavoriteColor: Color
    
    @EnvironmentObject var favoritesManager: FavoritesManager
    @State private var isAnimating = false
    
    enum HeartButtonSize {
        case small, medium, large
        
        var iconSize: CGFloat {
            switch self {
            case .small: return DSLayout.smallIcon
            case .medium: return DSLayout.icon
            case .large: return DSLayout.largeIcon
            }
        }
        
        var font: Font {
            return .system(size: iconSize, weight: .medium)
        }
        
        var frameSize: CGFloat {
            switch self {
            case .small: return DSLayout.icon + DSLayout.tightGap
            case .medium: return DSLayout.largeIcon + DSLayout.elementGap
            case .large: return DSLayout.largeIcon + DSLayout.contentGap
            }
        }
    }
    
    enum HeartButtonStyle {
        case minimal, interactive, prominent
        
        var hasHaptic: Bool {
            switch self {
            case .minimal: return false
            case .interactive, .prominent: return true
            }
        }
        
        var hasAnimation: Bool {
            return self == .prominent
        }
        
        var animationScale: CGFloat {
            return hasAnimation ? 1.15 : 1.0
        }
    }
    
    var body: some View {
        Button(action: toggleFavorite) {
            ZStack {
                if style.hasAnimation && isAnimating {
                    Circle()
                        .fill(DSColor.error.opacity(0.2))
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .opacity(isAnimating ? 0 : 0.6)
                        .animation(.easeOut(duration: 0.5), value: isAnimating)
                }
                
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(size.font)
                    .foregroundStyle(heartColor)
                    .scaleEffect(isAnimating ? style.animationScale : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAnimating)
            }
        }
        .frame(width: size.frameSize, height: size.frameSize)
        .disabled(favoritesManager.isLoading)
    }
    
    private var isFavorite: Bool {
        return favoritesManager.isFavorite(song.id)
    }
    
    private var heartColor: Color {
        return Color.white
    }
    
    private func toggleFavorite() {
        if style.hasHaptic {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        if style.hasAnimation {
            withAnimation(DSAnimations.spring) {
                isAnimating = true
            }
            
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation(DSAnimations.spring) {
                    isAnimating = false
                }
            }
        }
        
        Task {
            await favoritesManager.toggleFavorite(song)
        }
    }
}

// MARK: - Convenience Initializers

extension HeartButton {
    static func songRow(song: Song) -> HeartButton {
        HeartButton(song: song, size: .small, style: .interactive, unfavoriteColor: DSColor.secondary)
    }
    
    static func miniPlayer(song: Song) -> HeartButton {
        HeartButton(song: song, size: .medium, style: .interactive, unfavoriteColor: DSColor.onDark.opacity(0.8))
    }
    
    static func fullScreen(song: Song) -> HeartButton {
        HeartButton(song: song, size: .large, style: .prominent, unfavoriteColor: DSColor.onDark.opacity(0.8))
    }
}
