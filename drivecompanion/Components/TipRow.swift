//
//  TipRow.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 11/07/26.
//

import SwiftUI

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.black)
                .frame(width: 20)

            Text(text)
                .font(.body)
                .foregroundStyle(Color.black)
        }
    }
}

#Preview {
    TipRow(icon: "bell.slash", text: "Contoh tip row")
}
