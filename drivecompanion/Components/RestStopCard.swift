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

    private var distanceText: String {
        candidate.distance < 1000
        ? "\(Int(candidate.distance)) m"
        : String(format: "%.1f km", candidate.distance / 1000)
    }
    
    private var estimatedArrivalText: String? {
        guard let minutes = candidate.estimatedMinutes else { return nil }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return "\(minutes) min"
        } else if remainingMinutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(remainingMinutes) min"
        }
    }
    
    private var subtitleText: String {
        guard let estimatedArrivalText else {
            return "\(candidate.category) · \(distanceText)"
        }
        return "\(candidate.category) · \(distanceText) · \(estimatedArrivalText)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.name)
                        .font(AppFont.cardTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(subtitleText)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textSecondary)
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

            PrimaryButton("Mampir", iconName: "arrow.triangle.turn.up.right.circle") {
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
            distance: 3200,
            estimatedMinutes: 4),
        onAccept: {},
        onDismiss: {})
}
