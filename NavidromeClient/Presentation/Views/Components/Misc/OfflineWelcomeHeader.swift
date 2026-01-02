//
//  OfflineWelcomeHeader.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//

import SwiftUI

struct OfflineWelcomeHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.8))
            
            Text("Offline Mode")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("You are currently offline. Accessing your downloaded library.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
