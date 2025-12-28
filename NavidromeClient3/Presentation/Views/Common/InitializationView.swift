//
//  InitializationView.swift
//  NavidromeClient
//
//  Swift 6: Fixed DesignSystem font references
//

import SwiftUI

struct InitializationView: View {
    let initializer: AppInitializer
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: DSLayout.elementGap) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Initializing...")
                    // FIX: 'DSText.headline' -> 'DSText.prominent' (matches DesignSystem.swift)
                    .font(DSText.prominent)
                    .foregroundColor(DSColor.onDark)
                
                if case .inProgress = initializer.state {
                    Text("Loading your music library")
                        .font(DSText.body)
                        .foregroundColor(DSColor.onDarkSecondary)
                }
            }
        }
    }
}

struct InitializationErrorView: View {
    let error: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: DSLayout.elementGap) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(DSColor.error)
            
            Text("Initialization Failed")
                // FIX: 'DSText.title2' -> 'DSText.subsectionTitle' (matches DesignSystem.swift)
                .font(DSText.subsectionTitle)
            
            Text(error)
                .font(DSText.body)
                .foregroundColor(DSColor.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DSLayout.contentPadding)
            
            Button("Retry") {
                retry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DSLayout.screenPadding)
    }
}
