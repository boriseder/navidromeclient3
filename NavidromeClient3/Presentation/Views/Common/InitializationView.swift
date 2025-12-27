//
//  InitializationView.swift
//  NavidromeClient
//
//  Swift 6: Updated for @Observable
//

import SwiftUI

struct InitializationView: View {
    // FIX: Just use 'let'. The view will update automatically when 'initializer' properties change.
    let initializer: AppInitializer
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: DSLayout.elementGap) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Initializing...")
                    .font(DSText.headline) // Use DesignSystem
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
                .font(DSText.title2)
            
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
