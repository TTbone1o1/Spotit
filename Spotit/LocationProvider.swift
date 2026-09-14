//
//  LocationProvider.swift
//  Spotit
//

import Combine
import CoreLocation

@MainActor
final class LocationProvider: NSObject, ObservableObject {
    @Published private(set) var location: GeoPoint?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isRequestingAuthorization = false

    private let manager = CLLocationManager()
    private let simulatesHarajuku: Bool
    private var hasStarted = false

    var isSimulatingLocation: Bool { simulatesHarajuku }

    init(simulatesHarajuku: Bool) {
        self.simulatesHarajuku = simulatesHarajuku

        if simulatesHarajuku {
            location = GeoPoint(longitude: 139.7027, latitude: 35.6702)
        }

        super.init()

        authorizationStatus = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }

    func start() {
        guard !simulatesHarajuku else { return }

        hasStarted = true
        refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            requestAuthorization()
        }
    }

    // Authorization is real even when Discover uses the development location.
    // Both screens share this manager; only an explicit action requests access.
    func requestAuthorization() {
        refreshAuthorizationStatus()
        guard authorizationStatus == .notDetermined, !isRequestingAuthorization else { return }

        isRequestingAuthorization = true
        manager.requestWhenInUseAuthorization()
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus != .notDetermined {
            isRequestingAuthorization = false
        }

        guard hasStarted, !simulatesHarajuku else { return }
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .notDetermined, .denied, .restricted:
            manager.stopUpdatingLocation()
        @unknown default:
            break
        }
    }

    func moveSimulatedLocation(to location: GeoPoint) {
        guard simulatesHarajuku else { return }
        self.location = location
    }
}

extension LocationProvider: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refreshAuthorizationStatus()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !simulatesHarajuku, let latestLocation = locations.last else { return }

        location = GeoPoint(
            longitude: latestLocation.coordinate.longitude,
            latitude: latestLocation.coordinate.latitude
        )
    }
}
