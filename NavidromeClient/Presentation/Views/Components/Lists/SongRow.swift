//
//  SongRow.swift
//  NavidromeClient
//
//  PROFESSIONAL VERSION - Clean, Scannable, Premium
//  - Album thumbnails for visual anchors
//  - Proper typography hierarchy
//  - Visual rhythm through spacing
//  - Subtle depth on playing state
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
    let isLastInGroup: Bool
    let isFavorited: Bool
    
    @Environment(ThemeManager.self) var theme
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(CoverArtManager.self) var coverArtManager
    
    // Interaction states
    @State private var isPressed: Bool = false
    @State private var showPlayIndicator: Bool = false
    @State private var isHoveringRow: Bool = false
    @State private var hasAppeared: Bool = false
    @State private var showQuickActions: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            mainContent
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    trailingSwipeActions
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    leadingSwipeActions
                }
            
            // Micro-spacing every 3-4 songs for visual rhythm
            if shouldShowSpacing {
                Spacer()
                    .frame(height: 10)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 8)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DSAnimations.spring, value: isPressed)
        .animation(DSAnimations.ease, value: isPlaying)
        .animation(.spring(duration: 0.25).delay(Double(index) * 0.02), value: hasAppeared)
        .onAppear {
            if isPlaying {
                showPlayIndicator = true
            }
            hasAppeared = true
        }
        .onChange(of: isPlaying) { _, newValue in
            withAnimation(DSAnimations.springSnappy) {
                showPlayIndicator = newValue
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            triggerHapticFeedback()
            action()
        }
        .onLongPressGesture(
            minimumDuration: 0.3,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(DSAnimations.easeQuick) {
                    isPressed = pressing
                }
                if pressing {
                    triggerHapticFeedback(.medium)
                }
            },
            perform: {
                showQuickActions = true
                triggerHapticFeedback(.heavy)
            }
        )
        .contextMenu {
            enhancedContextMenu
        }
        .sheet(isPresented: $showQuickActions) {
            QuickActionsSheet(
                song: song,
                playerVM: playerVM,
                favoriteAction: favoriteAction,
                isFavorited: isFavorited
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAction {
            action()
        }
    }
    
    // MARK: - Visual Rhythm Helper
    
    private var shouldShowSpacing: Bool {
        // Add spacing every 3-4 songs (varying rhythm feels more natural)
        let pattern = [3, 4, 3, 4, 3] // Creates: 3 songs, space, 4 songs, space, etc.
        let position = index % pattern.reduce(0, +)
        var accumulated = 0
        
        for count in pattern {
            accumulated += count
            if position + 1 == accumulated && !isLastInGroup {
                return true
            }
        }
        return false
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        HStack(spacing: 12) {
            // Album thumbnail (visual anchor)
            albumThumbnail
                .frame(width: 48, height: 48)
            
            // Song info with hierarchy
            songInfoSection
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Duration
            durationSection
            
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(rowBackground)
        .contentShape(Rectangle())
    }
    
    // MARK: - Album Thumbnail (The Visual Anchor)
    
    // MARK: - Album Thumbnail (The Visual Anchor)
        
    @ViewBuilder
    private var albumThumbnail: some View {
        ZStack {
            if isPlaying && showPlayIndicator {
                // Show equalizer over dimmed artwork
                ZStack {
                    if let albumId = song.albumId {
                        AlbumImageView(albumId: albumId, context: .list)
                            .frame(width: 48, height: 48)
                            .overlay(Color.black.opacity(0.4))
                    } else {
                        placeholderArtwork
                            .overlay(Color.black.opacity(0.4))
                    }
                    
                    EqualizerBars(
                        isActive: true,
                        accentColor: .white
                    )
                    .frame(width: 28, height: 28)
                }
            } else {
                // Normal state
                if let albumId = song.albumId {
                    AlbumImageView(albumId: albumId, context: .list)
                        .frame(width: 48, height: 48)
                        .overlay(playOverlay)
                } else {
                    placeholderArtwork
                        .overlay(playOverlay)
                }
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }

    private var placeholderArtwork: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: "music.note")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(width: 48, height: 48)
    }
    
    // Show play icon on hover
    @ViewBuilder
    private var playOverlay: some View {
        if isHoveringRow && !isPlaying {
            ZStack {
                Color.black.opacity(0.3)
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .transition(.opacity)
        }
    }

    // MARK: - Song Info with Proper Hierarchy
    
    private var songInfoSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Title - prominent
            Text(song.title)
                .font(.system(size: 17, weight: isPlaying ? .semibold : .medium))
                .foregroundStyle(isPlaying ? DSColor.playing : DSColor.onDark)
                .lineLimit(1)
            
            // Artist/metadata - subtle
            if context != .album, let artist = song.artist, !artist.isEmpty {
                Text(artist)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DSColor.onDark.opacity(0.55))
                    .lineLimit(1)
            }
        }
    }
    
    // MARK: - Duration
    
    @ViewBuilder
    private var durationSection: some View {
        if let duration = song.duration, duration > 0 {
            HStack(spacing: 4) {
                if isPlaying {
                    Circle()
                        .fill(DSColor.playing)
                        .frame(width: 5, height: 5)
                }
                
                Text(formatDuration(duration))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(isPlaying ? DSColor.playing : DSColor.onDark.opacity(0.4))
                    .monospacedDigit()
            }
        }
    }
    
    // MARK: - Row Background with Subtle Depth
    
    private var rowBackground: some View {
        ZStack {
            // Playing state: subtle background + left accent
            if isPlaying {
                HStack(spacing: 0) {
                    // Left accent bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DSColor.playing)
                        .frame(width: 3)
                        .padding(.vertical, 4)
                    
                    // Background fill
                    Rectangle()
                        .fill(DSColor.playing.opacity(0.08))
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Subtle glow for depth
                RoundedRectangle(cornerRadius: 8)
                    .fill(DSColor.playing.opacity(0.06))
                    .blur(radius: 8)
                    .offset(y: 1)
            }
            
            // Pressed state
            if isPressed {
                RoundedRectangle(cornerRadius: 8)
                    .fill(DSColor.accent.opacity(0.12))
            }
            
            // Hover state (desktop)
            if isHoveringRow && !isPlaying && !isPressed {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.backgroundContrastColor.opacity(0.3))
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHoveringRow = hovering
            }
        }
    }
    
    // MARK: - Swipe Actions
    
    @ViewBuilder
    private var trailingSwipeActions: some View {
        Button {
            triggerHapticFeedback(.light)
            playerVM.playNext([song])
        } label: {
            Label("Next", systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        .tint(.blue)
        
        Button {
            triggerHapticFeedback(.light)
            playerVM.addToQueue([song])
        } label: {
            Label("Queue", systemImage: "text.append")
        }
        .tint(.orange)
    }
    
    @ViewBuilder
    private var leadingSwipeActions: some View {
        if let favoriteAction = favoriteAction {
            Button {
                triggerHapticFeedback(.medium)
                favoriteAction()
            } label: {
                Label(
                    isFavorited ? "Unlove" : "Love",
                    systemImage: isFavorited ? "heart.slash.fill" : "heart.fill"
                )
            }
            .tint(.red)
        }
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
        
        Divider()
        
        Button {
            // Navigate to album
        } label: {
            Label("Go to Album", systemImage: "square.stack")
        }
        
        if let artist = song.artist, !artist.isEmpty {
            Button {
                // Navigate to artist
            } label: {
                Label("Go to Artist", systemImage: "music.mic")
            }
        }
        
        Divider()
        
        if let favoriteAction = favoriteAction {
            Button {
                favoriteAction()
            } label: {
                Label(
                    isFavorited ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: isFavorited ? "heart.slash" : "heart.fill"
                )
            }
        }
        
        Button {
            // Add to playlist functionality
        } label: {
            Label("Add to Playlist", systemImage: "plus")
        }
        
        Divider()
        
        Button {
            // Show song info
        } label: {
            Label("Song Info", systemImage: "info.circle")
        }
        
        Button {
            // Share song
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
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
        return "Double tap to \(isPlaying ? "pause" : "play"). Swipe left for queue options, swipe right to favorite."
    }
}


// MARK: - Convenience Initializers

extension SongRow {
    init(
        song: Song,
        index: Int,
        isPlaying: Bool,
        action: @escaping () -> Void,
        context: SongRowContext = .album,
        isLastInGroup: Bool = false
    ) {
        self.init(
            song: song,
            index: index,
            isPlaying: isPlaying,
            action: action,
            favoriteAction: nil,
            context: context,
            isLastInGroup: isLastInGroup,
            isFavorited: false
        )
    }
}


// MARK: - Quick Actions Sheet

struct QuickActionsSheet: View {
    let song: Song
    let playerVM: PlayerViewModel
    let favoriteAction: (() -> Void)?
    let isFavorited: Bool
    
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) var theme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Song header
                VStack(spacing: 8) {
                    Text(song.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DSColor.onDark)
                        .multilineTextAlignment(.center)
                    
                    if let artist = song.artist {
                        Text(artist)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(DSColor.onDark.opacity(0.6))
                    }
                }
                .padding(.top, 20)
                
                Divider()
                    .padding(.horizontal)
                
                // Actions
                VStack(spacing: 0) {
                    QuickActionButton(
                        title: "Play Next",
                        icon: "text.line.first.and.arrowtriangle.forward",
                        color: .blue
                    ) {
                        playerVM.playNext([song])
                        dismiss()
                    }
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    QuickActionButton(
                        title: "Add to Queue",
                        icon: "text.append",
                        color: .orange
                    ) {
                        playerVM.addToQueue([song])
                        dismiss()
                    }
                    
                    if let favoriteAction = favoriteAction {
                        Divider()
                            .padding(.leading, 60)
                        
                        QuickActionButton(
                            title: isFavorited ? "Remove from Favorites" : "Add to Favorites",
                            icon: isFavorited ? "heart.slash.fill" : "heart.fill",
                            color: .red
                        ) {
                            favoriteAction()
                            dismiss()
                        }
                    }
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    QuickActionButton(
                        title: "Add to Playlist",
                        icon: "plus.circle.fill",
                        color: .green
                    ) {
                        dismiss()
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.backgroundContrastColor.opacity(0.3))
                )
                .padding(.horizontal)
                
                Spacer()
            }
            .background(theme.backgroundColor)
            .navigationTitle("Quick Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 28)
                
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DSColor.onDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DSColor.onDark.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
