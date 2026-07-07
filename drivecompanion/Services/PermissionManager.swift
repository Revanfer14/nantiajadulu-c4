//
//  PermissionManager.swift
//  drivecompanion
//
//  Created by Michelle Nathania on 03/07/26.
//

import Foundation
import AVFoundation
import CoreLocation

// blm masukin ke plist -mici
@MainActor
final class PermissionManager: NSObject {
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<Void, Never>?
}

// MARK: - Public API
extension PermissionManager {
    func requestPermissions() async {
        await requestCamera()
        _ = await SpeechInput.requestAuthorization() // this function already exists in Speech > SpeechInput
        await requestLocation()
    }
}

// MARK: - Private Extensions
// MARK: Camera
private extension PermissionManager {
    func requestCamera() async {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { _ in
                continuation.resume()
            }
        }
    }
}

// MARK: Location
private extension PermissionManager {
    func requestLocation() async {
        locationManager.delegate = self
        
        await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }
}

// MARK: - Location Manager Delegate
extension PermissionManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationContinuation?.resume()
        locationContinuation = nil
    }
}
