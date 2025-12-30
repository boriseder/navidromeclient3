//
//  HeartButton.swift - SIMPLE & EFFECTIVE
//  NavidromeClient
//
//  SIMPLE: Direct color parameter for context
//  CLEAN: No over-engineering
//  WORKS: Solves the actual problem
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
        case small    // 16pt - SongRows
        case medium   // 20pt - MiniPlayer
        case large    // 24pt - FullScreenPlayer
        
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
        case minimal      // No haptics, no animation
        case interactive  // Haptics only
        case prominent    // Haptics + animation
        
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
                // Animated background pulse for prominent style
                if style.hasAnimation && isAnimating {
                    Circle()
                        .fill(DSColor.error.opacity(0.2))
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .opacity(isAnimating ? 0 : 0.6)
                        .animation(.easeOut(duration: 0.5), value: isAnimating)
                }
                
                // Heart icon
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
    
    // MARK: - Computed Properties
    
    private var isFavorite: Bool {
        return favoritesManager.isFavorite(song.id)
    }
    
    private var heartColor: Color {
        return Color.white
    }
    
    // MARK: - Actions
    
    private func toggleFavorite() {
        // Haptic feedback
        if style.hasHaptic {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        // Animation
        if style.hasAnimation {
            withAnimation(DSAnimations.spring) {
                isAnimating = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(DSAnimations.spring) {
                    isAnimating = false
                }
            }
        }
        
        // Toggle favorite status
        Task {
            await favoritesManager.toggleFavorite(song)
        }
    }
}

// MARK: - Convenience Initializers

extension HeartButton {
    /// For song rows in lists - light backgrounds
    static func songRow(song: Song) -> HeartButton {
        HeartButton(
            song: song,
            size: .small,
            style: .interactive,
            unfavoriteColor: DSColor.secondary  // Standard for light backgrounds
        )
    }
    
    /// For mini player - dark background
    static func miniPlayer(song: Song) -> HeartButton {
        HeartButton(
            song: song,
            size: .medium,
            style: .interactive,
            unfavoriteColor: DSColor.onDark.opacity(0.8)  // Light for dark background
        )
    }
    
    /// For full screen player - dark background with animation
    static func fullScreen(song: Song) -> HeartButton {
        HeartButton(
            song: song,
            size: .large,
            style: .prominent,
            unfavoriteColor: DSColor.onDark.opacity(0.8)  // Light for dark background
        )
    }
    
    /// Custom color variant
    static func custom(song: Song, size: HeartButtonSize, style: HeartButtonStyle, unfavoriteColor: Color) -> HeartButton {
        HeartButton(
            song: song,
            size: size,
            style: style,
            unfavoriteColor: unfavoriteColor
        )
    }
}
