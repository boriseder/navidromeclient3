import SwiftUI
import Combine // FIX: Added import

struct EqualizerBars: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .frame(height: isAnimating ? CGFloat.random(in: 8...20) : 5)
                    .animation(
                        .easeInOut(duration: 0.2).repeatForever().delay(Double(i) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}
