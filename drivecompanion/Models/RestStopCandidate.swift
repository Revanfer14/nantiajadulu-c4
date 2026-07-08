//
//  RestStopCandidate.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 06/07/26.
//

import CoreLocation
import MapKit

nonisolated struct RestStopCandidate: Identifiable {
    let id: UUID
    let mapItem: MKMapItem
    let name: String
    let category: String
    let coordinate: CLLocationCoordinate2D
    let distance: CLLocationDistance
    let estimatedMinutes: Int?

    init(id: UUID = UUID(), mapItem: MKMapItem, name: String, category: String, coordinate: CLLocationCoordinate2D, distance: CLLocationDistance, estimatedMinutes: Int? = nil) {
        self.id = id
        self.mapItem = mapItem
        self.name = name
        self.category = category
        self.coordinate = coordinate
        self.distance = distance
        self.estimatedMinutes = estimatedMinutes
    }

    func withEstimatedMinutes(_ minutes: Int?) -> RestStopCandidate {
        RestStopCandidate(id: id, mapItem: mapItem, name: name, category: category, coordinate: coordinate, distance: distance, estimatedMinutes: minutes)
    }
}
