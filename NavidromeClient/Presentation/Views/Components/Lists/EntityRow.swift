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
                .foregroundColor(theme.textColor)
                .lineLimit(1)
        
            Spacer()
            
            trailing
        }
        .padding(.vertical, DSLayout.elementPadding)
        .background(
            // Hintergrund wie in SongRow: Nur bei Interaktion/Hover leicht sichtbar
            ZStack {
                if isHovering {
                    RoundedRectangle(cornerRadius: DSCorners.element)
                        .fill(theme.backgroundContrastColor.opacity(0.15))
                } else {
                    RoundedRectangle(cornerRadius: DSCorners.element)
                        .fill(theme.textColor.opacity(0.02))
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
