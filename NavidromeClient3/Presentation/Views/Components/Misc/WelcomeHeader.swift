//
//  WelcomeHeader.swift
//  NavidromeClient
//
//  Created by Boris Eder on 12.09.25.
//

import SwiftUI

// Less intrusive
import SwiftUI

struct WelcomeHeader: View {
    let username: String
    let nowPlaying: Song?
    @EnvironmentObject var offlineManager: OfflineManager
    
    @State private var showingNetworkTestView = false
    @State private var showingCoverArtDebugView = false
    
    // MARK: - Mehrsprachige Grüße nach Tageszeit
    private let greetingsByTime: [String: [String]] = [
        "morning": ["Good morning", "Bonjour", "Guten Morgen", "おはようございます", "Buongiorno"],
        "afternoon": ["Good afternoon", "Bon après-midi", "Guten Tag", "Buenas tardes", "Buon pomeriggio"],
        "evening": ["Good evening", "Bonsoir", "Guten Abend", "Buonasera", "こんばんは"],
        "night": ["Good night", "Bonne nuit", "Gute Nacht", "おやすみなさい", "Buonanotte"]
    ]


    // MARK: - Body
    var body: some View {
        ZStack(alignment: .leading) {
            // Hintergrundgradient
            LinearGradient(
                colors: gradientColors(),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .horizontal)
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: DSCorners.element, style: .continuous))
            .shadow(radius: 8, y: 4)

            // Inhalt
            HStack {
                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text("\(timeBasedGreeting()), \(username)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Button {
                    offlineManager.toggleOfflineMode()
                } label: {
                    Image(systemName: nowPlaying == nil ? "music.note" : "waveform")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding()
                        .background(.white.opacity(0.15))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, DSLayout.screenPadding)
        }
        .padding(.top, DSLayout.contentPadding)
    }

    // MARK: - Helper Methods
    private func gradientColors() -> [Color] {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return [Color.orange, Color.pink]
        case 12..<17: return [Color.blue, Color.cyan]
        case 17..<22: return [Color.purple, Color.indigo]
        default: return [Color.black, Color.teal]
        }
    }

    private func timeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeKey: String
        switch hour {
        case 5..<12: timeKey = "morning"
        case 12..<17: timeKey = "afternoon"
        case 17..<22: timeKey = "evening"
        default: timeKey = "night"
        }
        return greetingsByTime[timeKey]?.randomElement() ?? "Hello"
    }
}

