//
//  ListLayoutWrapper.swift
//  NavidromeClient
//
//  Created by EDER Boris (ICS480-ECC) on 07.05.26.
//


import SwiftUI

struct ListLayoutWrapper<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content
    
    // Default spacing ist tightGap, da Artists und Genres dies zuvor verwendet haben
    init(spacing: CGFloat = DSLayout.tightGap, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: spacing) {
                content()
            }
            .padding(.bottom, DSLayout.miniPlayerHeight)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, DSLayout.screenPadding)
    }
}