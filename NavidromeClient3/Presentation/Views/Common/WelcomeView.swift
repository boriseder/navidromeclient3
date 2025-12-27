import SwiftUI

struct WelcomeView: View {
    // FIX: Swift 6 Observable Syntax
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        VStack(spacing: DSLayout.sectionGap) {
            Spacer()
            
            WelcomeHeader()
            
            VStack(spacing: DSLayout.contentGap) {
                Text("Welcome to Navidrome")
                    .font(DSText.largeTitle)
                    .foregroundColor(DSColor.primary)
                
                Text("Your personal music streamer")
                    .font(DSText.body)
                    .foregroundColor(DSColor.secondary)
            }
            
            Spacer()
            
            // Example usage of themeManager if needed, or just context
            // Button(...)
        }
        .padding(DSLayout.screenPadding)
        .background(DSColor.background)
    }
}
