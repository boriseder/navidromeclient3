import SwiftUI

struct EntityRow<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing
    
    @Environment(ThemeManager.self) var theme

    var body: some View {
        // HStack Spacing 12: In deinem DSLayout gibt es keine 12.
        // Wir setzen es aus elementGap (8) + tightGap (4) zusammen.
        HStack(spacing: DSLayout.elementGap + DSLayout.tightGap) {
            leading
            
            Text(title)
                .font(DSText.emphasized)
                .foregroundStyle(DSColor.onDark)
                .lineLimit(1)
        
            Spacer()
            
            trailing
        }
        // Horizontal 16 = contentPadding
        .padding(.horizontal, DSLayout.contentPadding)
        // Vertikal 12 = elementPadding (8) + tightPadding (4)
        .padding(.vertical, DSLayout.elementPadding + DSLayout.tightPadding)
        .background(
            // Transparenz (0.3) und Ecken (8 = DSCorners.element)
            theme.backgroundContrastColor.opacity(0.3),
            in: RoundedRectangle(cornerRadius: DSCorners.element)
        )
    }
}
