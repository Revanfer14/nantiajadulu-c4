//
//  AlertStateView.swift
//  drivecompanion
//
//  Created by Stephanie Vania Suwardi Data on 06/07/26.
//

import SwiftUI


struct AlertStateView2: View {
   // let message: String // Menerima teks dinamis
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title)
            Text("guling")
                .font(.body)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color("cream"))
        
        
    }
}

#Preview {
    AlertStateView2()
}
