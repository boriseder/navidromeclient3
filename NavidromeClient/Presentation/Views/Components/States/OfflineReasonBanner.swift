//
//  OfflineReasonBanner.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Fixed type reference for nested enum
//

import SwiftUI

struct OfflineReasonBanner: View {
    let reason: ContentLoadingStrategy.OfflineReason
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reason.icon)
                .font(.system(size: 16, weight: .semibold))
            
            Text(reason.message)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            if reason.canGoOnline {
                Button(reason.actionTitle) {
                    reason.performAction()
                }
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(reason.color)
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 4)
    }
}
