//
//  OfflineReasonBanner.swift
//  NavidromeClient3
//
//  Swift 6: Fixed - Now accepts 'reason' from ContentView
//

import SwiftUI

struct OfflineReasonBanner: View {
    @Environment(OfflineManager.self) private var offlineManager
    
    // FIX: Restored this property so ContentView can pass the specific reason
    let reason: ContentLoadingStrategy.OfflineReason
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reason.icon)
                .font(.title3)
                .foregroundStyle(reason.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(reason.title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                
                Text(reason.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            // Only show button if the reason allows going online (e.g. User Choice)
            if reason.canGoOnline {
                Button("Go Online") {
                    offlineManager.switchToOnlineMode()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(reason.color)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .background(reason.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
