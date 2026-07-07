//
//  ChatBubble.swift
//  drivecompanion
//
//  Created by Stephanie Vania Suwardi Data on 06/07/26.
//

import SwiftUI

struct ChatBubble: View {
    let turn: ChatTurn
    
    var isUser: Bool {
        turn.role == .user
    }
    
    var body: some View {
        
     
            
            HStack {
                if isUser { Spacer() } // Dorong balon user ke kanan
                
                Text(turn.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isUser ? Color.blue : Color(.systemGray5)) // Biru untuk user, abu untuk AI
                    .foregroundColor(isUser ? .white : .primary)
                    .clipShape(RoundedCorner(radius: 18, corners: isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight]))
                
                if !isUser { Spacer() } // Dorong balon AI ke kiri
            }
            .padding(isUser ? .leading : .trailing, 60) // Beri jarak agar balon tidak terlalu lebar
            .padding(.vertical, 4)
        
     
        
    }
}

// Helper untuk membuat sudut melengkung spesifik
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview("Simulasi Obrolan") {
    ScrollView {
        VStack(spacing: 12) {
            // Tampilan Driver (Kanan, Biru)
            ChatBubble(
                turn: ChatTurn(
                    role: .user,
                    text: "Capek banget gua hari ini, macet banget dari tadi pas pulang kuliah."
                )
            )
            
            // Tampilan AI (Kiri, Abu-abu)
            ChatBubble(
                turn: ChatTurn(
                    role: .model,
                    text: "Anjir sama, dari tadi gua liat maps merah semua. Lu udah dari jam berapa di jalan?"
                )
            )
        }
        .padding()
    }
}
