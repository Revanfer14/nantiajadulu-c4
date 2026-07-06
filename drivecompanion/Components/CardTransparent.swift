//
//  CardTransparent.swift
//  drivecompanion
//
//  Created by Michelle Nathania on 03/07/26.
//

import SwiftUI

struct CardTransparent: View {
    let title: String
    let iconName: String
    let description: String
    
    init(_ title: String, iconName: String, description: String) {
        self.title = title
        self.iconName = iconName
        self.description = description
    }
    
    var body: some View {
        HStack (spacing: 12) {
            Image(systemName: iconName)
                .font(AppFont.iconSize)
                .foregroundStyle(AppColor.appPrimary)
                .frame(width: 50, height: 50)
            
            VStack (alignment: .leading) {
                Text(title)
                    .font(AppFont.cardTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColor.textPrimary)
                Text(description)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }
}

#Preview {
    CardTransparent("Title", iconName: "camera.circle", description: "Lorem ipsum dolor sit amet lalala lilili halo mintje")
}
