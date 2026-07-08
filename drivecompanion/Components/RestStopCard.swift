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
            return "\(minutes) mnt"
        } else if remainingMinutes == 0 {
            return "\(hours)j"
        } else {
            return "\(hours)j \(remainingMinutes) mnt"
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
        List {
            Button(action: onAccept) {
                RestStopRow(candidate: candidate)
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .listRowBackground(Color(
                red: 232/255,
                green: 244/255,
                blue: 251/255
            ))
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .frame(height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .simultaneousGesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height < -40 {
                        onDismiss()
                    }
                }
        )
    }
}

#Preview {
    RestStopCard(
        candidate: RestStopCandidate(
            mapItem: MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8))),
            name: "Rest Area KM 72",
            category: "SPBU",
            coordinate: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8),
            distance: 6000,
            estimatedMinutes: 16),
        onAccept: {},
        onDismiss: {})
}
