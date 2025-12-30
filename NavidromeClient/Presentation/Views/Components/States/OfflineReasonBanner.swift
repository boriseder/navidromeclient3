//
//  OfflineReasonBanner.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//

import SwiftUI

struct OfflineReasonBanner: View {
    let reason: ContentLoadingStrategy.OfflineReason
    
    var body: some View{
        Button {
            reason.performAction()
        } label: {
            HStack(spacing: DSLayout.elementGap) {
                Image(systemName: reason.icon)
                Text("Offline")
            }
            .foregroundColor(.white)
            .padding(DSLayout.elementPadding)
        }
        .background(Color.red.opacity(0.7))
        .clipShape(Capsule())
        .shadow(radius: 4)
    }
}
