//
//  OfflineReasonBanner.swift
//  NavidromeClient3
//
//  Swift 6: Fixed to accept 'reason' argument & use Strategy properties
//

import SwiftUI

struct OfflineReasonBanner: View {
    @Environment(OfflineManager.self) private var offlineManager
    
    // FIX: Added property to accept the argument from ContentView
    let reason: ContentLoadingStrategy.OfflineReason
    
    var body: some View {
        HStack {
            Image(systemName: reason.icon)
            
            // Use the rich message from the strategy instead of hardcoded text
            Text(reason.message)
                .font(.callout)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            // Only show button if the reason allows going online (e.g. User Choice)
            if reason.canGoOnline {
                Button(reason.actionTitle) {
                    offlineManager.switchToOnlineMode()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(reason.color.opacity(0.2))
        .cornerRadius(8)
    }
}
