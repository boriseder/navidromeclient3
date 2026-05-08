//
//  SettingsRow.swift
//  NavidromeClient
//
//  Created by EDER Boris (ICS480-ECC) on 08.05.26.
//


//
//  SettingsComponents.swift
//  NavidromeClient
//
//  Small reusable components used across Settings screens.
//

import SwiftUI

// MARK: - SettingsRow

struct SettingsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - CacheStatsRow

struct CacheStatsRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - FactoryResetOverlayView

struct FactoryResetOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Resetting App...")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Clearing all data and settings")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}