//
//  GridLayoutWrapper.swift
//  NavidromeClient
//
//  Created by EDER Boris (ICS480-ECC) on 07.05.26.
//


import SwiftUI

struct GridLayoutWrapper<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: GridColumns.two,
                alignment: .leading,
                spacing: DSLayout.contentGap
            ) {
                content()
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, DSLayout.screenPadding)
    }
}
