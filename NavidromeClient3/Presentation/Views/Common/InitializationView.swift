//
//  InitializationView.swift
//  NavidromeClient
//
//  UI for displaying app initialization state and errors.
//

import SwiftUI

struct InitializationView: View {
    @ObservedObject var initializer: AppInitializer
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: DSLayout.elementGap) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Initializing...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if case .inProgress = initializer.state {
                    Text("Loading your music library")
                        .font(.subheadline)
                        .foregroundColor(.gray)
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
                .foregroundColor(.red)
            
            Text("Initialization Failed")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                retry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
