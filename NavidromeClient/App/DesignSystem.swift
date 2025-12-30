import SwiftUI

// MARK: - Layout (Namespace)

enum DSLayout {
    // MARK: Gaps
    static let tightGap: CGFloat = 4
    static let elementGap: CGFloat = 8
    static let contentGap: CGFloat = 16
    static let sectionGap: CGFloat = 24
    static let screenGap: CGFloat = 32
    static let largeGap: CGFloat = 40
    
    // MARK: Padding
    static let tightPadding: CGFloat = 4
    static let elementPadding: CGFloat = 8
    static let contentPadding: CGFloat = 16
    static let comfortPadding: CGFloat = 24
    static let screenPadding: CGFloat = 16
    
    // MARK: Fixed Sizes
    static let buttonHeight: CGFloat = 44
    static let searchBarHeight: CGFloat = 44
    static let tabBarHeight: CGFloat = 90
    static let miniPlayerHeight: CGFloat = 49
    
    // MARK: Icon Sizes
    static let smallIcon: CGFloat = 16
    static let icon: CGFloat = 24
    static let largeIcon: CGFloat = 32
    
    // MARK: Cover/Avatar Sizes
    static let miniCover: CGFloat = 50
    static let listCover: CGFloat = 70
    static let cardCover: CGFloat = 150
    static let cardCoverNoPadding: CGFloat = 168
    static let detailCover: CGFloat = 300
    static let fullCover: CGFloat = 400
    static let smallAvatar: CGFloat = 72
    static let avatar: CGFloat = 100
    
    // MARK: Max Widths
    static let maxContentWidth: CGFloat = 400
}

// MARK: - Corners

enum DSCorners {
    static let tight: CGFloat = 3
    static let element: CGFloat = 8
    static let content: CGFloat = 16
    static let comfortable: CGFloat = 24
    static let spacious: CGFloat = 32
    static let round: CGFloat = 50
}

// MARK: - Typography

enum DSText {
    // MARK: Hierarchy
    static let pageTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let sectionTitle = Font.system(.title, design: .rounded).weight(.bold)
    static let subsectionTitle = Font.system(.title2, design: .rounded).weight(.semibold)
    static let itemTitle = Font.system(.title3, design: .rounded).weight(.semibold)
    
    // MARK: Content
    static let prominent = Font.headline.weight(.semibold)
    static let emphasized = Font.subheadline.weight(.medium)
    static let body = Font.body
    static let detail = Font.callout
    
    // MARK: Small text
    static let metadata = Font.caption
    static let fine = Font.caption2
    static let footnote = Font.footnote
    
    // MARK: Interactive
    static let button = Font.callout.weight(.semibold)
    static let largeButton = Font.headline.weight(.semibold)
    
    // MARK: Special
    static let numbers = Font.body.monospacedDigit()
}

// MARK: - Colors

enum DSColor {
    // MARK: Content
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let tertiary = Color(.tertiaryLabel)
    static let quaternary = Color(.quaternaryLabel)
    
    // MARK: Surfaces
    static let background = Color(.black)
    static let surface = Color(.secondarySystemBackground)
    static let surfaceSecondary = Color(.tertiarySystemBackground)
    static let surfaceLight = Color(UIColor.systemGray6)
    static let surfaceMedium = Color(UIColor.systemGray5)
    
    // MARK: Brand & Status
    static let accent = Color.accentColor
    static let brand = Color.blue
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue
    
    // MARK: Music-specific
    static let playing = Color.blue
    static let offline = Color.orange
    static let downloaded = Color.green
    
    // MARK: On-colors
    static let onDark = Color.white
    static let onDarkSecondary = Color.white.opacity(0.7)
    static let onLight = Color.black
    static let onLightSecondary = Color.black.opacity(0.7)
    
    // MARK: Overlays
    static let overlay = Color.black.opacity(0.4)
    static let overlayLight = Color.black.opacity(0.2)
    static let overlayHeavy = Color.black.opacity(0.6)
}

enum DSMaterial {
    static let background: Material = .ultraThin
}

enum DSAnimations {
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let ease = Animation.easeInOut(duration: 0.2)
    static let easeQuick = Animation.easeInOut(duration: 0.1)
    static let easeSlow = Animation.easeInOut(duration: 0.4)
    
    // Interactive
    static let interactive = Animation.interactiveSpring()
    static let bounce = Animation.spring(response: 0.6, dampingFraction: 0.6)
}

// MARK: - Grid Helpers

enum GridColumns {
    static let two = Array(repeating: GridItem(.flexible(), spacing: DSLayout.contentGap, alignment: .leading), count: 2)
    static let three = Array(repeating: GridItem(.flexible(), spacing: DSLayout.elementGap, alignment: .leading), count: 3)
    static let four = Array(repeating: GridItem(.flexible(), spacing: DSLayout.elementGap, alignment: .leading), count: 4)
}
