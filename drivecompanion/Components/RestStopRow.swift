//
//  RestStopRow.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 07/07/26.
//

import SwiftUI
import MapKit

struct RestStopRow: View {
    let candidate: RestStopCandidate
    
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
    
    private var iconName: String {
        switch candidate.category {
        case "SPBU": return "fuelpump.fill"
        case "Restoran": return "fork.knife"
        case "Kafe": return "cup.and.saucer.fill"
        case "Parkir": return "parkingsign"
        case "Pengisian EV": return "bolt.car.fill"
        case "Rest Area": return "bed.double.fill"
        case "Masjid": return "building.2.fill"
        default: return "mappin.and.ellipse"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(
                    red: 42/255,
                    green: 91/255,
                    blue: 156/255
                ))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.name)
                    .font(AppFont.body)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(subtitleText)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
    }
}

#Preview {
    RestStopRow(candidate: RestStopCandidate(
        mapItem: MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8))),
        name: "Rest Area KM 72",
        category: "SPBU",
        coordinate: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8),
        distance: 6000,
        estimatedMinutes: 16))
}
