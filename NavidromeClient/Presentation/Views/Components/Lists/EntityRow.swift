import SwiftUI

struct EntityRow<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing
    
    @Environment(ThemeManager.self) var theme
    @State private var isHovering = false

    var body: some View {
        // Spacing 12
        HStack(spacing: DSLayout.elementGap + DSLayout.tightGap) {
            leading
            
            Text(title)
                .font(DSText.emphasized)
                .foregroundStyle(DSColor.onDark)
                .lineLimit(1)
        
            Spacer()
            
            trailing
        }
        // Padding 16 horizontal, 12 vertikal
        .padding(.horizontal, DSLayout.contentPadding)
        .padding(.vertical, DSLayout.elementPadding + DSLayout.tightPadding)
        .background(
            // Hintergrund wie in SongRow: Nur bei Interaktion/Hover leicht sichtbar
            ZStack {
                if isHovering {
                    RoundedRectangle(cornerRadius: DSCorners.element)
                        .fill(theme.backgroundContrastColor.opacity(0.15))
                } else {
                    Color.clear
                }
            }
        )
        // Wichtig, damit die ganze (transparente) Zeile klickbar bleibt
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(DSAnimations.ease) {
                isHovering = hovering
            }
        }
    }
}
