//
//  PrimaryButton.swift
//  drivecompanion
//
//  Created by Michelle Nathania on 03/07/26.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let iconName: String?
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    init(_ title: String, iconName: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.iconName = iconName
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack (spacing: 8) {
                if let icon = iconName {
                    Image(systemName: icon)
                        .fontWeight(.bold)
                }

                Text(title)
            }
            .foregroundStyle(AppColor.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? AppColor.appPrimary : Color(red: 182 / 255, green: 179 / 255, blue: 179 / 255))
            .clipShape(Capsule())
            .glassEffect()
        }
    }
}

#Preview {
    PrimaryButton("Button Text", action: {})
}
