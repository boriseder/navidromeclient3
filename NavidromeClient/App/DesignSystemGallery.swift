import SwiftUI

struct DesignSystemGallery: View {
    @State private var animationToggle = false
    
    var body: some View {
        NavigationStack {
            List {
                typographySection
                colorSection
                cornerSection
                layoutSection
                gridSection
                animationSection
                materialSection
            }
            .navigationTitle("Design System Gallery")
        }
    }
    
    // MARK: - 1. Typography
    private var typographySection: some View {
        Section(header: Text("Typography")) {
            VStack(alignment: .leading, spacing: DSLayout.elementGap) {
                Text("Hierarchies").font(DSText.metadata).foregroundColor(DSColor.secondary)
                Text("Page Title").font(DSText.pageTitle)
                Text("Section Title").font(DSText.sectionTitle)
                Text("Subsection Title").font(DSText.subsectionTitle)
                Text("Item Title").font(DSText.itemTitle)
            }
            .padding(.vertical, DSLayout.tightPadding)
            
            VStack(alignment: .leading, spacing: DSLayout.elementGap) {
                Text("Content").font(DSText.metadata).foregroundColor(DSColor.secondary)
                Text("Prominent").font(DSText.prominent)
                Text("Emphasized").font(DSText.emphasized)
                Text("Body").font(DSText.body)
                Text("Detail").font(DSText.detail)
            }
            .padding(.vertical, DSLayout.tightPadding)
            
            VStack(alignment: .leading, spacing: DSLayout.elementGap) {
                Text("Small & Interactive").font(DSText.metadata).foregroundColor(DSColor.secondary)
                Text("Metadata").font(DSText.metadata)
                Text("Fine").font(DSText.fine)
                Text("Footnote").font(DSText.footnote)
                Text("Button").font(DSText.button).foregroundColor(DSColor.accent)
                Text("Large Button").font(DSText.largeButton).foregroundColor(DSColor.accent)
                Text("Numbers: 123,456.78").font(DSText.numbers)
            }
            .padding(.vertical, DSLayout.tightPadding)
        }
    }
    
    // MARK: - 2. Colors
    private var colorSection: some View {
        Section(header: Text("Colors")) {
            Group {
                Text("Content & Surfaces").font(DSText.emphasized)
                ColorRow(name: "Primary", color: DSColor.primary)
                ColorRow(name: "Secondary", color: DSColor.secondary)
                ColorRow(name: "Tertiary", color: DSColor.tertiary)
                ColorRow(name: "Quaternary", color: DSColor.quaternary)
                ColorRow(name: "Background", color: DSColor.background)
                ColorRow(name: "Surface", color: DSColor.surface)
                ColorRow(name: "Surface Secondary", color: DSColor.surfaceSecondary)
                ColorRow(name: "Surface Light", color: DSColor.surfaceLight)
                ColorRow(name: "Surface Medium", color: DSColor.surfaceMedium)
            }
            
            Group {
                Text("Brand & Status").font(DSText.emphasized)
                ColorRow(name: "Accent", color: DSColor.accent)
                ColorRow(name: "Brand", color: DSColor.brand)
                ColorRow(name: "Success", color: DSColor.success)
                ColorRow(name: "Warning", color: DSColor.warning)
                ColorRow(name: "Error", color: DSColor.error)
                ColorRow(name: "Info", color: DSColor.info)
            }
            
            Group {
                Text("Music-Specific").font(DSText.emphasized)
                ColorRow(name: "Playing", color: DSColor.playing)
                ColorRow(name: "Offline", color: DSColor.offline)
                ColorRow(name: "Downloaded", color: DSColor.downloaded)
            }
            
            Group {
                Text("On-Colors (Contrast Check)").font(DSText.emphasized)
                ColorRow(name: "On Dark", color: DSColor.onDark)
                    .listRowBackground(Color.black)
                ColorRow(name: "On Dark Secondary", color: DSColor.onDarkSecondary)
                    .listRowBackground(Color.black)
                ColorRow(name: "On Light", color: DSColor.onLight)
                    .listRowBackground(Color.white)
                ColorRow(name: "On Light Secondary", color: DSColor.onLightSecondary)
                    .listRowBackground(Color.white)
            }
            
            Group {
                Text("Overlays").font(DSText.emphasized)
                ColorRow(name: "Overlay (40%)", color: DSColor.overlay)
                ColorRow(name: "Overlay Light (20%)", color: DSColor.overlayLight)
                ColorRow(name: "Overlay Heavy (60%)", color: DSColor.overlayHeavy)
            }
        }
    }
    
    // MARK: - 3. Corners
    private var cornerSection: some View {
        Section(header: Text("Corners")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSLayout.contentGap) {
                    CornerBox(name: "Tight (3)", radius: DSCorners.tight)
                    CornerBox(name: "Element (8)", radius: DSCorners.element)
                    CornerBox(name: "Content (16)", radius: DSCorners.content)
                    CornerBox(name: "Comfortable (24)", radius: DSCorners.comfortable)
                    CornerBox(name: "Spacious (32)", radius: DSCorners.spacious)
                    CornerBox(name: "Round (50)", radius: DSCorners.round)
                }
                .padding(.vertical, DSLayout.elementPadding)
            }
        }
    }
    
    // MARK: - 4. Layout & Sizes
    private var layoutSection: some View {
        Section(header: Text("Layout & Sizes")) {
            Group {
                Text("Gaps").font(DSText.emphasized)
                SizeRow(name: "Tight Gap", size: DSLayout.tightGap)
                SizeRow(name: "Element Gap", size: DSLayout.elementGap)
                SizeRow(name: "Content Gap", size: DSLayout.contentGap)
                SizeRow(name: "Section Gap", size: DSLayout.sectionGap)
                SizeRow(name: "Screen Gap", size: DSLayout.screenGap)
                SizeRow(name: "Large Gap", size: DSLayout.largeGap)
            }
            
            Group {
                Text("Paddings").font(DSText.emphasized)
                SizeRow(name: "Tight Padding", size: DSLayout.tightPadding)
                SizeRow(name: "Element Padding", size: DSLayout.elementPadding)
                SizeRow(name: "Content Padding", size: DSLayout.contentPadding)
                SizeRow(name: "Comfort Padding", size: DSLayout.comfortPadding)
                SizeRow(name: "Screen Padding", size: DSLayout.screenPadding)
            }
            
            Group {
                Text("Fixed Heights & Widths").font(DSText.emphasized)
                SizeRow(name: "Button Height", size: DSLayout.buttonHeight)
                SizeRow(name: "Search Bar Height", size: DSLayout.searchBarHeight)
                SizeRow(name: "Tab Bar Height", size: DSLayout.tabBarHeight)
                SizeRow(name: "Mini Player Height", size: DSLayout.miniPlayerHeight)
                SizeRow(name: "Max Content Width", size: DSLayout.maxContentWidth)
            }
            
            Group {
                Text("Icons").font(DSText.emphasized)
                SizeRow(name: "Small Icon", size: DSLayout.smallIcon)
                SizeRow(name: "Icon", size: DSLayout.icon)
                SizeRow(name: "Large Icon", size: DSLayout.largeIcon)
            }
            
            Group {
                Text("Covers & Avatars").font(DSText.emphasized)
                SizeRow(name: "Mini Cover", size: DSLayout.miniCover)
                SizeRow(name: "List Cover", size: DSLayout.listCover)
                SizeRow(name: "Card Cover", size: DSLayout.cardCover)
                SizeRow(name: "Card Cover No Pad", size: DSLayout.cardCoverNoPadding)
                SizeRow(name: "Detail Cover", size: DSLayout.detailCover)
                SizeRow(name: "Full Cover", size: DSLayout.fullCover)
                SizeRow(name: "Small Avatar", size: DSLayout.smallAvatar)
                SizeRow(name: "Avatar", size: DSLayout.avatar)
            }
        }
    }
    
    // MARK: - 5. Grids
    private var gridSection: some View {
        Section(header: Text("Grid Columns")) {
            VStack(alignment: .leading, spacing: DSLayout.sectionGap) {
                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text("GridColumns.two").font(DSText.emphasized)
                    LazyVGrid(columns: GridColumns.two) {
                        ForEach(0..<2) { _ in GridItemBox() }
                    }
                }
                
                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text("GridColumns.three").font(DSText.emphasized)
                    LazyVGrid(columns: GridColumns.three) {
                        ForEach(0..<3) { _ in GridItemBox() }
                    }
                }
                
                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text("GridColumns.four").font(DSText.emphasized)
                    LazyVGrid(columns: GridColumns.four) {
                        ForEach(0..<4) { _ in GridItemBox() }
                    }
                }
            }
            .padding(.vertical, DSLayout.tightPadding)
        }
    }
    
    // MARK: - 6. Animations
    private var animationSection: some View {
        Section(header: Text("Animations")) {
            Button(action: {
                animationToggle.toggle()
            }) {
                Text("Toggle Animations")
                    .font(DSText.button)
                    .frame(maxWidth: .infinity)
                    .frame(height: DSLayout.buttonHeight)
                    .background(DSColor.brand)
                    .foregroundColor(DSColor.onDark)
                    .cornerRadius(DSCorners.element)
            }
            .buttonStyle(.plain)
            .padding(.vertical, DSLayout.elementPadding)
            
            VStack(spacing: DSLayout.contentGap) {
                AnimationRow(name: "Spring", animation: DSAnimations.spring, isActive: animationToggle)
                AnimationRow(name: "Spring Snappy", animation: DSAnimations.springSnappy, isActive: animationToggle)
                AnimationRow(name: "Ease", animation: DSAnimations.ease, isActive: animationToggle)
                AnimationRow(name: "Ease Quick", animation: DSAnimations.easeQuick, isActive: animationToggle)
                AnimationRow(name: "Ease Slow", animation: DSAnimations.easeSlow, isActive: animationToggle)
                AnimationRow(name: "Interactive", animation: DSAnimations.interactive, isActive: animationToggle)
                AnimationRow(name: "Bounce", animation: DSAnimations.bounce, isActive: animationToggle)
            }
        }
    }
    
    // MARK: - 7. Materials
    private var materialSection: some View {
        Section(header: Text("Materials")) {
            ZStack {
                LinearGradient(colors: [DSColor.brand, DSColor.warning], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 120)
                    .cornerRadius(DSCorners.content)
                
                Text("DSMaterial.background (.ultraThin)")
                    .font(DSText.prominent)
                    .foregroundColor(DSColor.primary)
                    .padding(DSLayout.contentPadding)
                    .background(DSMaterial.background)
                    .cornerRadius(DSCorners.element)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            }
            .padding(.vertical, DSLayout.elementPadding)
        }
    }
}

// MARK: - Subviews & Helpers

struct ColorRow: View {
    let name: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
            Circle()
                .fill(color)
                .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
                .overlay(Circle().stroke(DSColor.surfaceMedium, lineWidth: 1))
            
            Text(name)
                .font(DSText.body)
            
            Spacer()
        }
    }
}

struct CornerBox: View {
    let name: String
    let radius: CGFloat
    
    var body: some View {
        VStack(spacing: DSLayout.elementGap) {
            Rectangle()
                .fill(DSColor.brand)
                .frame(width: 65, height: 65)
                .cornerRadius(radius)
            
            Text(name)
                .font(DSText.fine)
                .foregroundColor(DSColor.secondary)
        }
    }
}

struct SizeRow: View {
    let name: String
    let size: CGFloat
    
    var body: some View {
        HStack {
            Text(name)
                .font(DSText.detail)
                .frame(width: 140, alignment: .leading)
            
            // Ein skaliertes Rechteck, damit Werte wie 400pt das Layout nicht sprengen
            Rectangle()
                .fill(DSColor.accent.opacity(0.7))
                .frame(width: min(size * 0.4, 120), height: 8)
                .cornerRadius(DSCorners.tight)
            
            Spacer()
            
            Text("\(Int(size)) pt")
                .font(DSText.numbers)
                .foregroundColor(DSColor.secondary)
        }
    }
}

struct GridItemBox: View {
    var body: some View {
        Rectangle()
            .fill(DSColor.surfaceMedium)
            .frame(height: 45)
            .cornerRadius(DSCorners.element)
            .overlay(
                Text("Item")
                    .font(DSText.fine)
                    .foregroundColor(DSColor.secondary)
            )
    }
}

struct AnimationRow: View {
    let name: String
    let animation: Animation
    let isActive: Bool
    
    var body: some View {
        HStack {
            Text(name)
                .font(DSText.body)
                .frame(width: 130, alignment: .leading)
            
            Spacer()
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DSColor.surfaceLight)
                    .frame(width: 100, height: 6)
                
                Circle()
                    .fill(DSColor.playing)
                    .frame(width: DSLayout.icon, height: DSLayout.icon)
                    .offset(x: isActive ? 76 : 0)
                    .animation(animation, value: isActive)
            }
            .frame(width: 100)
        }
    }
}

// MARK: - Preview
#Preview {
    DesignSystemGallery()
}
