//
//  Theme.swift
//  drivecompanion
//
//  Created by Michelle Nathania on 03/07/26.
//

import SwiftUI

// MARK: - App Color
enum AppColor {
    // MARK: Background
    static let primary = Color("Primary")
    static let background = Color("Background")
    
    // MARK: Text Color
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
}

// MARK: - App Font
enum AppFont {
    static let screenTitle = Font.largeTitle
    static let sectionTitle = Font.title
    static let cardTitle = Font.headline
    static let body = Font.body
    
    static let iconSize = Font.system(size: 40)
}

#Preview {
    Text("Halo")
        .font(AppFont.cardTitle)
}
