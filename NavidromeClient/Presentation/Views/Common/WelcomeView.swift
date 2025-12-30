//
//  WelcomeView.swift - Enhanced with Design System
//  NavidromeClient
//
//   ENHANCED: Vollständige Anwendung des Design Systems
//

import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void
    
    var body: some View {
        ZStack {
            
            DynamicMusicBackground()

            VStack(spacing: DSLayout.screenGap) {
            Image(systemName: "music.note.house")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DSColor.accent, DSColor.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: DSLayout.contentGap) {
                Text("Welcome to Navidrome Client")
                    .font(DSText.pageTitle)
                    .multilineTextAlignment(.center)
                
                Text("Connect to your Navidrome server to start listening to your music library")
                    .font(DSText.body)
                    .foregroundStyle(DSColor.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Get Started") {
                onGetStarted()
            }
            .font(DSText.largeButton)
        }
            .padding(DSLayout.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }
}
