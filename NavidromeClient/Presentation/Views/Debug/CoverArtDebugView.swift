//
//  CoverArtDebugView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//

import SwiftUI

struct CoverArtDebugView: View {
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    var body: some View {
        let stats = coverArtManager.getCacheStats()
        let health = coverArtManager.getHealthStatus()
        
        VStack(spacing: 16) {
            Text("Cover Art Diagnostics")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Health:")
                    Text(health.statusDescription)
                        .foregroundColor(health.isHealthy ? .green : .orange)
                        .bold()
                }
                
                Text("Cache Generation: \(coverArtManager.cacheGeneration)")
                
                Divider()
                
                Text("Disk Cache")
                    .font(.subheadline)
                    .bold()
                Text("Entries: \(stats.diskCount)")
                Text("Size: \(stats.diskSizeFormatted)")
                
                Divider()
                
                Text("Network")
                    .font(.subheadline)
                    .bold()
                Text("Active Requests: \(stats.activeRequests)")
                Text("Errors: \(stats.errorCount)")
                
                if stats.activeRequests + stats.errorCount > 0 {
                    let errorRate = Double(stats.errorCount) / Double(stats.activeRequests + stats.errorCount)
                    Text("Error Rate: \(String(format: "%.1f%%", errorRate * 100))")
                        .foregroundColor(errorRate > 0.1 ? .red : .green)
                }
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                Button("Reset Stats") {
                    coverArtManager.resetPerformanceStats()
                }
                .buttonStyle(.bordered)
                
                Button("Clear Cache") {
                    coverArtManager.clearMemoryCache()
                }
                .buttonStyle(.bordered)
                
                Button("Print Logs") {
                    coverArtManager.printDiagnostics()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
