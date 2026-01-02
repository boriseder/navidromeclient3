//
//  InitializationView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Bindable for observable passing
//

import SwiftUI

struct InitializationView: View {
    @Bindable var initializer: AppInitializer
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image("AppIcon") // Assuming app icon asset exists, or use system image
                    .resizable()
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)
                
                Text("Navidrome Client")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if initializer.state == .inProgress {
                    ProgressView()
                        .tint(.white)
                    Text("Starting up...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct InitializationErrorView: View {
    let error: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            
            Text("Initialization Failed")
                .font(.headline)
            
            Text(error)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Retry", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
