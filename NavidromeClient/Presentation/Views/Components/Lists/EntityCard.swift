//
//  EntityCard.swift
//  NavidromeClient
//
//  Created by EDER Boris (ICS480-ECC) on 07.05.26.
//


import SwiftUI

struct EntityCard<ImageContent: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let imageContent: ImageContent
    
    @Environment(ThemeManager.self) var theme
    
    // Die 160 stammen aus deinem alten CardItemContainer
    var cardWidth: CGFloat = 160 
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.elementGap) {
            imageContent
                .frame(width: cardWidth, height: cardWidth)
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(title)
                    .font(DSText.body)
                    .foregroundStyle(theme.textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DSText.detail)
                        .foregroundStyle(theme.textColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: cardWidth, alignment: .leading)
        }
        .frame(width: cardWidth)
        .padding(.bottom, DSLayout.elementPadding)
    }
}
