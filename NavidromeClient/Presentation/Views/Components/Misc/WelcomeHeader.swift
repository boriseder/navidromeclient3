//
//  WelcomeHeader.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//

import SwiftUI

struct WelcomeHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 60))
                .symbolEffect(.bounce, options: .repeating)
                .foregroundStyle(.white)
                .padding(.bottom, 8)
            
            Text("Welcome to Navidrome")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            
            Text("Your music, everywhere.")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}
