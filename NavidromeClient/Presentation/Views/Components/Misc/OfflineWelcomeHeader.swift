//
//  OfflineWelcomeHeader.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//

import SwiftUI

struct OfflineWelcomeHeader: View {
    let downloadedAlbums: Int
    let isConnected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.elementGap) {
            Text(statusText)
                .font(DSText.body)
                .foregroundColor(DSColor.onDark)
        }
    }
    
    private var statusText: String {
        if downloadedAlbums == 0 {
            return "No downloaded music available"
        } else {
            return "\(downloadedAlbums) album\(downloadedAlbums != 1 ? "s" : "") available offline"
        }
    }
}
