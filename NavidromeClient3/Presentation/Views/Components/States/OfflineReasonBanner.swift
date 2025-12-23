//
//  OfflineReasonBanner.swift
//  NavidromeClient
//
//  Created by Boris Eder on 26.09.25.
//
import SwiftUI

// New component for consistent offline messaging
struct OfflineReasonBanner: View {
    let reason: ContentLoadingStrategy.OfflineReason
    @EnvironmentObject private var offlineManager: OfflineManager
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    
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
    
    /*
    var body: some View {
        HStack(spacing: DSLayout.elementGap) {

     Image(systemName: reason.icon)
                .foregroundStyle(reason.color)
                .padding(.leading, DSLayout.elementPadding)
            
            Text(reason.message)
                .font(DSText.metadata)
                .foregroundStyle(reason.color)
                .multilineTextAlignment(.leading)
                .padding(.vertical, DSLayout.elementPadding)


            Spacer()
            
            if reason.canGoOnline {
                Button("reason.actionTitle") {
                    reason.performAction()
                }
                .font(DSText.metadata)
                .foregroundStyle(DSColor.accent)
                .padding(.trailing, DSLayout.contentPadding)
            }
        }
        .background(
            reason.color.opacity(0.2),
            in: RoundedRectangle(cornerRadius: DSCorners.element)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSCorners.element)
                .stroke(reason.color.opacity(0.3), lineWidth: 1)
        )
        .padding(.trailing, 45)

    }
     */
}

