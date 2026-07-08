//
//  DrowsinessStatusPill.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 08/07/26.
//

import SwiftUI

struct DrowsinessStatusPill: View {
    let state: DrowsinessState

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))

            Text(label)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(tintColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor, in: Capsule())
        .overlay(Capsule().strokeBorder(tintColor.opacity(0.3), lineWidth: 0.5))
        .animation(.easeInOut(duration: 0.25), value: state)
    }

    private var iconName: String {
        switch state {
        case .noFace: "eye.slash"
        case .alert: "eye"
        case .drowsy: "exclamationmark.triangle"
        case .microsleep: "exclamationmark.octagon.fill"
        }
    }

    private var label: String {
        switch state {
        case .noFace: "Wajah tidak terdeteksi"
        case .alert: "Siaga"
        case .drowsy: "Mengantuk"
        case .microsleep: "Microsleep"
        }
    }

    private var tintColor: Color {
        switch state {
        case .noFace: .secondary
        case .alert: .green
        case .drowsy: .orange
        case .microsleep: .red
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .noFace: Color(.systemGray5)
        case .alert: Color.green.opacity(0.15)
        case .drowsy: Color.orange.opacity(0.15)
        case .microsleep: Color.red.opacity(0.15)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        DrowsinessStatusPill(state: .noFace)
        DrowsinessStatusPill(state: .alert)
        DrowsinessStatusPill(state: .drowsy)
        DrowsinessStatusPill(state: .microsleep)
    }
    .padding()
}
