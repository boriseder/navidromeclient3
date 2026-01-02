//
//  WelcomeView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Compliance
//

import SwiftUI

struct WelcomeView: View {
    var onContinue: () -> Void
    
    @Environment(ThemeManager.self) var theme
    
    var body: some View {
        ZStack {
            DynamicMusicBackground()
            
            VStack(spacing: 40) {
                Spacer()
                WelcomeHeader()
                Spacer()
                
                VStack(spacing: 24) {
                    FeatureRow(icon: "music.note.house", title: "Your Personal Stream", description: "Stream your entire music collection.")
                    FeatureRow(icon: "arrow.down.circle", title: "Offline Playback", description: "Download music for offline listening.")
                    FeatureRow(icon: "hifispeaker.2", title: "High Quality Audio", description: "Experience high fidelity playback.")
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("Connect Server")
                        .font(.headline) // Fixed: Use system headline
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(theme.accent)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline) // Fixed: Use system headline
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}
