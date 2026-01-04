//
//  SongRow.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Compliance with FULL UI/UX Restored
//  - All animations, haptics, and visual polish from old version
//  - Modern @Environment instead of @EnvironmentObject
//  - Proper context handling for album vs favorites
//

import SwiftUI
import Observation

enum SongRowContext {
    case album
    case favorites
    case playlist
    case search
}

struct SongRow: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let action: () -> Void
    let favoriteAction: (() -> Void)?
    let context: SongRowContext
    
    @Environment(ThemeManager.self) var theme
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(CoverArtManager.self) var coverArtManager
    
    // Interaction states for better UX
    @State private var isPressed: Bool = false
    @State private var showPlayIndicator: Bool = false
    
    // REMOVE: playIndicatorPhase (not needed)
    // REMOVE: animationTimer (EqualizerBars handles its own animation)
    
    var body: some View {
        VStack(spacing: DSLayout.elementGap) {
            HStack(spacing: DSLayout.elementGap) {
                trackNumberSection
                    .padding(.leading, DSLayout.elementGap)
                
                songInfoSection
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                durationSection
                    .padding(.trailing, DSLayout.elementGap)
            }
            .padding(.vertical, DSLayout.contentPadding)
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DSAnimations.spring, value: isPressed)
        .animation(DSAnimations.ease, value: isPlaying)
        // REMOVE: .onReceive(animationTimer)
        .onAppear {
            if isPlaying { showPlayIndicator = true }
        }
        .onChange(of: isPlaying) { _, newValue in
            withAnimation(DSAnimations.springSnappy) {
                showPlayIndicator = newValue
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            triggerHapticFeedback()
            withAnimation(DSAnimations.easeQuick) {
                action()
            }
        }
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(DSAnimations.easeQuick) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
        .contextMenu {
            enhancedContextMenu
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAction {
            action()
        }
    }
    
    // MARK: - Track Number Section
    
    @ViewBuilder
    private var trackNumberSection: some View {
        ZStack {
            if isPlaying && showPlayIndicator {
                EqualizerBars(
                    isActive: true,  // ← EqualizerBars animates itself
                    accentColor: DSColor.playing
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            } else {
                if context == .album {
                    Text("\(song.track ?? index).")
                        .font(DSText.emphasized)
                        .foregroundStyle(DSColor.onDark)
                        .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                } else {
                    HeartButton.songRow(song: song)
                        .onTapGesture {
                            triggerHapticFeedback(.light)
                            favoriteAction?()
                        }
                        .font(DSText.emphasized)
                        .foregroundStyle(DSColor.onDark)
                        .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
        }
        .animation(DSAnimations.springSnappy, value: showPlayIndicator)
        .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
    }

    // MARK: - Song Info Section
    
    private var songInfoSection: some View {
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            // Song title
            Text(song.title)
                .font(DSText.emphasized)
                .foregroundStyle(songColor)
                .lineLimit(1)
            
            // Show artist for non-album contexts
            if context != .album, let artist = song.artist, !artist.isEmpty {
                Text(artist)
                    .font(DSText.metadata)
                    .foregroundStyle(DSColor.onDark)
                    .lineLimit(1)
            }
        }
    }
    
    private var songColor: Color {
        if isPlaying {
            return DSColor.playing
        }
        return DSColor.onDark
    }
    
    // MARK: - Duration Section
    
    @ViewBuilder
    private var durationSection: some View {
        if let duration = song.duration, duration > 0 {
            Text(formatDuration(duration))
                .font(DSText.emphasized)
                .foregroundStyle(songColor)
        }
    }
    
    // MARK: - Row Background
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: DSCorners.tight)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: DSCorners.tight)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
    
    // Dynamic background styling
    private var backgroundColor: Color {
        if isPressed {
            return DSColor.accent.opacity(0.45)
        } else if isPlaying {
            return DSColor.background
        } else {
            return theme.backgroundContrastColor.opacity(0.44)
        }
    }
    
    private var borderColor: Color {
        if isPlaying {
            return DSColor.playing.opacity(0.2)
        } else {
            return DSColor.quaternary.opacity(0.3)
        }
    }
    
    private var borderWidth: CGFloat {
        isPlaying ? 1 : 0.5
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private var enhancedContextMenu: some View {
        Button {
            action()
        } label: {
            Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
        }
        
        Button {
            playerVM.playNext([song])
        } label: {
            Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        
        Button {
            playerVM.addToQueue([song])
        } label: {
            Label("Add to Queue", systemImage: "text.append")
        }
        
        if let favoriteAction = favoriteAction {
            Divider()
            Button(action: favoriteAction) {
                Label("Toggle Favorite", systemImage: "heart.fill")
            }
        }
        
        Divider()
        
        Button {
            // Add to playlist functionality
        } label: {
            Label("Add to Playlist", systemImage: "plus")
        }
    }
    
    // MARK: - Helper Methods
        
    private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        var label = "Track \(index): \(song.title)"
        if let artist = song.artist {
            label += " by \(artist)"
        }
        if let duration = song.duration {
            label += ", \(formatDuration(duration))"
        }
        if isPlaying {
            label += ", currently playing"
        }
        return label
    }
    
    private var accessibilityHint: String {
        return "Double tap to \(isPlaying ? "pause" : "play")"
    }
}


// MARK: - Convenience Initializers

extension SongRow {
    /// Initializer without favorite action (for album context)
    init(
        song: Song,
        index: Int,
        isPlaying: Bool,
        action: @escaping () -> Void,
        context: SongRowContext = .album
    ) {
        self.init(
            song: song,
            index: index,
            isPlaying: isPlaying,
            action: action,
            favoriteAction: nil,  // ← Key difference: no favorite action
            context: context
        )
    }
    
    // DELETE the second convenience initializer - it's identical to the main one!
    // The main initializer already handles the favoriteAction parameter
}
