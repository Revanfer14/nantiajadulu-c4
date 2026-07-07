//
//  RestStopCard.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 07/07/26.
//

import SwiftUI
import MapKit

struct RestStopCard: View {
    let candidate: RestStopCandidate
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.category)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textSecondary)
                    Text(candidate.name)
                        .font(AppFont.cardTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColor.textPrimary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }

            PrimaryButton("Mampir, \(String(format: "%.1f", candidate.distance / 1000)) km lagi", iconName: "arrow.triangle.turn.up.right.circle") {
                onAccept()
            }
        }
        .padding(16)
        .background(AppColor.background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(radius: 8)
        .padding(.horizontal, 16)
    }
}

#Preview {
    RestStopCard(
        candidate: RestStopCandidate(
            mapItem: MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8))),
            name: "SPBU Pertamina 123.456",
            category: "SPBU",
            coordinate: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8),
            distance: 3200),
        onAccept: {},
        onDismiss: {})
}
