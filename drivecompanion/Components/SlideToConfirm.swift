//
//  SlideToConfirm.swift
//  drivecompanion
//
//  Created by Revan Ferdinand on 09/07/26.
//

import SwiftUI

struct SlideToConfirm: View {
    let title: String
    let onConfirm: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isConfirmed = false

    private let knobSize: CGFloat = 46
    private let trackHeight: CGFloat = 54
    private let horizontalInset: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let maxOffset = max(geometry.size.width - knobSize - horizontalInset * 2, 0)
            let progress = maxOffset > 0 ? dragOffset / maxOffset : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColor.appPrimary)
                    .glassEffect()

                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .opacity(1 - progress)

                Circle()
                    .fill(Color.white)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .foregroundStyle(AppColor.appPrimary)
                    )
                    .offset(x: horizontalInset + dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !isConfirmed else { return }
                                dragOffset = min(max(value.translation.width, 0), maxOffset)
                            }
                            .onEnded { value in
                                guard !isConfirmed else { return }
                                if dragOffset >= maxOffset * 0.9 {
                                    isConfirmed = true
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                        dragOffset = maxOffset
                                    }
                                    onConfirm()
                                } else {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: trackHeight)
    }
}

#Preview {
    SlideToConfirm(title: "Geser untuk berhenti", onConfirm: {})
        .padding(.horizontal, 20)
}
