//
//  RestStopViewModel.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 07/07/26.
//

import CoreLocation
import Combine
import MapKit

final class RestStopViewModel: ObservableObject {
    @Published private(set) var suggestedStop: RestStopCandidate?
    @Published private(set) var originCoordinate: CLLocationCoordinate2D?
    
    private let locationService = LocationService()
    private let finder = RestStopFinder()
    
    private var currentCoordinate: CLLocationCoordinate2D?
    private var currentCourse: CLLocationDirection = -1
    
    init() {
        locationService.onLocationUpdate = { [weak self] coordinate, course, _ in
            self?.currentCoordinate = coordinate
            self?.currentCourse = course
            self?.originCoordinate = coordinate
        }
        locationService.start()
    }
    
    func stop() {
        locationService.stop()
    }
    
    func findCandidates() async -> [RestStopCandidate] {
        guard let coordinate = currentCoordinate else { return [] }
        return await finder.search(near: coordinate, course: currentCourse)
    }
    
    func fetchRoute(for candidate: RestStopCandidate) async -> MKRoute? {
        guard let coordinate = currentCoordinate else { return nil }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        request.destination = candidate.mapItem
        request.transportType = .automobile

        do {
            let response = try await MKDirections(request: request).calculate()
            return response.routes.first
        } catch {
            return nil
        }
    }
    
    func fetchEstimatedTime(for candidate: RestStopCandidate) async -> RestStopCandidate {
        guard let coordinate = currentCoordinate else { return candidate }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        request.destination = candidate.mapItem
        request.transportType = .automobile
        
        do {
            let response = try await MKDirections(request: request).calculateETA()
            let minutes = max(1, Int(response.expectedTravelTime / 60))
            return candidate.withEstimatedMinutes(minutes)
        } catch {
            return candidate
        }
    }
    
    func present(_ candidate: RestStopCandidate) {
        suggestedStop = candidate
    }
    
    func dismiss() {
        suggestedStop = nil
    }
    
    func confirm() {
        guard suggestedStop != nil else { return }
        suggestedStop = nil
    }
    
    func confirm() -> RestStopCandidate? {
        guard let candidate = suggestedStop else { return nil }
        suggestedStop = nil
        return candidate
    }

    func openInMaps(_ candidate: RestStopCandidate) {
        candidate.mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
