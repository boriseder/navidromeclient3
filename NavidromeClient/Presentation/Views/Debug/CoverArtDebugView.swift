//
//  CoverArtDebugView.swift
//  NavidromeClient
//
//  UPDATED: Settings UI Style
//

import SwiftUI

struct CoverArtDebugView: View {
    @Environment(CoverArtManager.self) var coverArtManager
    @Environment(ThemeManager.self) var theme
    
    var body: some View {
        let stats = coverArtManager.getCacheStats()
        let health = coverArtManager.getHealthStatus()
        
        List {
            // MARK: - Health Status Section
            Section {
                HStack {
                    Image(systemName: health.isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(health.isHealthy ? .green : .orange)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cache Health")
                            .font(.headline)
                        Text(health.statusDescription)
                            .font(.subheadline)
                            .foregroundStyle(health.isHealthy ? .green : .orange)
                    }
                    
                    Spacer()
                    
                    Text("Gen \(coverArtManager.cacheGeneration)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Status")
            }
            
            // MARK: - Disk Cache Section
            Section {
                LabeledStatRow(
                    icon: "internaldrive",
                    label: "Cache Entries",
                    value: "\(stats.diskCount)"
                )
                
                LabeledStatRow(
                    icon: "chart.bar.fill",
                    label: "Cache Size",
                    value: stats.diskSizeFormatted
                )
            } header: {
                Text("Disk Cache")
            }
            
            // MARK: - Network Section
            Section {
                LabeledStatRow(
                    icon: "arrow.down.circle",
                    label: "Active Requests",
                    value: "\(stats.activeRequests)",
                    valueColor: stats.activeRequests > 10 ? .orange : .primary
                )
                
                LabeledStatRow(
                    icon: "exclamationmark.triangle",
                    label: "Errors",
                    value: "\(stats.errorCount)",
                    valueColor: stats.errorCount > 0 ? .red : .green
                )
                
                if stats.activeRequests + stats.errorCount > 0 {
                    let errorRate = Double(stats.errorCount) / Double(stats.activeRequests + stats.errorCount)
                    LabeledStatRow(
                        icon: "percent",
                        label: "Error Rate",
                        value: String(format: "%.1f%%", errorRate * 100),
                        valueColor: errorRate > 0.1 ? .red : .green
                    )
                }
            } header: {
                Text("Network Performance")
            }
            
            // MARK: - Actions Section
            Section {
                Button {
                    coverArtManager.resetPerformanceStats()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset Statistics")
                        Spacer()
                    }
                }
                
                Button {
                    coverArtManager.clearMemoryCache()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Memory Cache")
                        Spacer()
                    }
                }
                .foregroundStyle(.orange)
                
                Button {
                    coverArtManager.printDiagnostics()
                } label: {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Print Diagnostics to Console")
                        Spacer()
                    }
                }
            } header: {
                Text("Actions")
            } footer: {
                Text("Reset statistics to clear counters. Clear cache to free memory. Print diagnostics outputs detailed logs to Xcode console.")
                    .font(.caption)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Cover Art Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Helper View

struct LabeledStatRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            Text(label)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundStyle(valueColor)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}
