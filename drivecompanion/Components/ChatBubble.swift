//
//  ChatBubble.swift
//  drivecompanion
//
//  Created by Stephanie Vania Suwardi Data on 06/07/26.
//

import SwiftUI

struct ChatBubble: View {
    let turn: ChatTurn

    private var isUser: Bool {
        turn.role == .user
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            Text(turn.text)
                .font(.system(size: 15))
                .multilineTextAlignment(isUser ? .trailing : .leading)
                .foregroundStyle(
                    isUser
                        ? Color(red: 60/255.0, green: 60/255.0, blue: 67/255.0)
                        : AppColor.textPrimary
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    isUser
                        ? Color(red: 244/255.0, green: 245/255.0, blue: 247/255.0)
                        : Color(red: 232/255.0, green: 244/255.0, blue: 251/255.0)
                )
                .clipShape(
                    isUser
                        ? UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, bottomTrailingRadius: 6, topTrailingRadius: 20)
                        : UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 6, bottomTrailingRadius: 20, topTrailingRadius: 20)
                )

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Simulasi Obrolan") {
    ScrollView {
        VStack(spacing: 12) {
            ChatBubble(turn: ChatTurn(role: .user, text: "Capek banget gua hari ini, macet banget dari tadi pas pulang kuliah."))
            ChatBubble(turn: ChatTurn(role: .model, text: "Anjir sama, dari tadi gua liat maps merah semua. Lu udah dari jam berapa di jalan?"))
        }
        .padding()
    }
}
