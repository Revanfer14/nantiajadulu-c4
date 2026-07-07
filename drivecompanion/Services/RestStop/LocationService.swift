//
//  LocationService.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 06/07/26.
//

import CoreLocation

final class LocationService: NSObject {
    private let manager = CLLocationManager()
    
    var onLocationUpdate: ((_ coordinate: CLLocationCoordinate2D, _ course: CLLocationDirection, _ speed: CLLocationSpeed) -> Void)?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .automotiveNavigation
        manager.distanceFilter = 20
    }
    
    func start() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            print("Location not authorized")
        }
    }
    
    func stop() {
        manager.stopUpdatingLocation()
    }
}

// get current coordinate and direction (course)
extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        guard let location = locations.last, location.course >= 0 else { return }
        guard let location = locations.last else { return }
        onLocationUpdate?(location.coordinate, location.course, location.speed)
    }
}
