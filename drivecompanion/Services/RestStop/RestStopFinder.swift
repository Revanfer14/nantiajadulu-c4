//
//  RestStopFinder.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 06/07/26.
//

import CoreLocation
import MapKit

nonisolated struct RestStopFinder {
    private let searchRadius: CLLocationDistance = 15000
    private let aheadConeDegrees: Double = 60
    private let maxResults = 5
    
    private let textQueries: [String: String] = [
        "rest area": "Rest Area",
        "masjid": "Masjid",
        "SPBU": "SPBU"
    ]
    
    // execute all func
    func search(near coordinate: CLLocationCoordinate2D, course: CLLocationDirection) async -> [RestStopCandidate] {
        async let categoryResults = searchByCategory(near: coordinate)
        async let textResults = searchByText(near: coordinate)
        
        let combined = await categoryResults + textResults
        let deduped = dedupe(combined)
        let ahead = deduped.filter { isAhead(of: coordinate, course: course, candidate: $0.coordinate) }
        
        return Array(ahead.sorted { $0.distance < $1.distance }.prefix(maxResults))
    }
    
    private func searchByCategory(near coordinate: CLLocationCoordinate2D) async -> [RestStopCandidate] {
        let request = MKLocalSearch.Request()
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.gasStation, .restaurant, .cafe, .parking, .evCharger])
        request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: searchRadius * 2, longitudinalMeters: searchRadius * 2)
        
        return await runSearch(request, near: coordinate, fallbackLabel: "Tempat Istirahat")
    }
    
    private func searchByText(near coordinate: CLLocationCoordinate2D) async -> [RestStopCandidate] {
        var results: [RestStopCandidate] = []
        for (query, label) in textQueries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = .pointOfInterest
            request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: searchRadius * 2, longitudinalMeters: searchRadius * 2)
            results += await runSearch(request, near: coordinate, fallbackLabel: label)
        }
        return results
    }
    
    // do the search
    private func runSearch(_ request: MKLocalSearch.Request, near coordinate: CLLocationCoordinate2D, fallbackLabel: String) async -> [RestStopCandidate] {
        do {
            let response = try await MKLocalSearch(request: request).start()
            let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            return response.mapItems.compactMap { item in
                guard let itemCoordinate = item.placemark.location?.coordinate else { return nil }
                let distance = origin.distance(from: CLLocation(latitude: itemCoordinate.latitude, longitude: itemCoordinate.longitude))
                guard distance <= searchRadius else { return nil }
                
                return RestStopCandidate(
                    mapItem: item,
                    name: item.name ?? fallbackLabel,
                    category: item.pointOfInterestCategory != nil ? label(for: item) : fallbackLabel,
                    coordinate: itemCoordinate,
                    distance: distance)
            }
        } catch {
            return []
        }
    }
    
    // check if a candidate is ahead from origin based on course/direction
    private func isAhead(of origin: CLLocationCoordinate2D, course: CLLocationDirection, candidate: CLLocationCoordinate2D) -> Bool {
        guard course >= 0 else { return true }
        let bearing = bearingBetween(origin, candidate)
        let diff = abs(bearing - course).truncatingRemainder(dividingBy: 360)
        return min(diff, 360 - diff) <= aheadConeDegrees
    }
    
    // calculate compass direction from origin to candidate
    private func bearingBetween(_ origin: CLLocationCoordinate2D, _ destination: CLLocationCoordinate2D) -> Double {
        let lat1 = origin.latitude * .pi / 180
        let lat2 = destination.latitude * .pi / 180
        let deltaLon = (destination.longitude - origin.longitude) * .pi / 180
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
    
    // remove duplicates
    private func dedupe(_ candidates: [RestStopCandidate]) -> [RestStopCandidate] {
        var seen = Set<String>()
        return candidates.filter { seen.insert(String(format: "%.4f,%.4f", $0.coordinate.latitude, $0.coordinate.longitude)).inserted }
    }
    
    private func label(for item: MKMapItem) -> String {
        switch item.pointOfInterestCategory {
        case .gasStation: return "SPBU"
        case .restaurant: return "Restoran"
        case .cafe: return "Kafe"
        case .parking: return "Parkir"
        case .evCharger: return "Pengisian EV"
        default: return "Tempat Istirahat"
        }
    }
}
