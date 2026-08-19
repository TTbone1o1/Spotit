//
//  LocationProvider.swift
//  Spotit
//

import Combine
import CoreLocation

@MainActor
final class LocationProvider: NSObject, ObservableObject {
    @Published private(set) var location: GeoPoint?

    private let manager = CLLocationManager()
    private let simulatesHarajuku: Bool

    init(simulatesHarajuku: Bool) {
        self.simulatesHarajuku = simulatesHarajuku

        if simulatesHarajuku {
            location = GeoPoint(longitude: 139.7027, latitude: 35.6702)
        }

        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }

    func start() {
        guard !simulatesHarajuku else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
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
        guard !simulatesHarajuku else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            manager.stopUpdatingLocation()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !simulatesHarajuku, let latestLocation = locations.last else { return }

        location = GeoPoint(
            longitude: latestLocation.coordinate.longitude,
            latitude: latestLocation.coordinate.latitude
        )
    }
}
