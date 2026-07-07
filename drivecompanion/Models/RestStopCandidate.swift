//
//  RestStopCandidate.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 06/07/26.
//

import CoreLocation
import MapKit

nonisolated struct RestStopCandidate: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
    let name: String
    let category: String
    let coordinate: CLLocationCoordinate2D
    let distance: CLLocationDistance
}
