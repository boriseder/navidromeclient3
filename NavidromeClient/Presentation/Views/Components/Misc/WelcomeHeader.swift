//
//  WelcomeHeader.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//

import SwiftUI

struct WelcomeHeader: View {
    let username: String
    let nowPlaying: Song?
    @EnvironmentObject var offlineManager: OfflineManager
    
    // MARK: - Greetings
    private let greetingsByTime: [String: [String]] = [
        "morning": ["Good morning", "Bonjour", "Guten Morgen", "Buongiorno"],
        "afternoon": ["Good afternoon", "Bon après-midi", "Guten Tag", "Buon pomeriggio"],
        "evening": ["Good evening", "Bonsoir", "Guten Abend", "Buonasera"],
        "night": ["Good night", "Bonne nuit", "Gute Nacht", "Buonanotte"]
    ]

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: gradientColors(),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .horizontal)
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: DSCorners.element, style: .continuous))
            .shadow(radius: 8, y: 4)

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
