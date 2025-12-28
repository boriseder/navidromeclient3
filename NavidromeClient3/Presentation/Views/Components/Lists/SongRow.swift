import SwiftUI

enum SongContext {
    case album,favorites
}

struct SongRow: View {
    let song: Song
    let trackNumber: Int?
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            if isPlaying {
                EqualizerBars()
                    .frame(width: 20, height: 20)
            } else if let track = trackNumber {
                Text("\(track)")
                    .font(DSText.metadata)
                    .foregroundColor(DSColor.secondary)
                    .frame(width: 20, alignment: .center)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(DSText.body)
                    .foregroundColor(isPlaying ? .accentColor : DSColor.primary)
                    .lineLimit(1)
                
                if let artist = song.artist {
                    Text(artist)
                        .font(DSText.metadata)
                        .foregroundColor(DSColor.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let duration = song.duration {
                Text(formatDuration(duration))
                    .font(DSText.metadata)
                    .foregroundColor(DSColor.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, DSLayout.contentPadding)
        .contentShape(Rectangle())
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
