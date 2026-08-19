//
//  FoodRecommendations.swift
//  Spotit
//

import CoreLocation
import Foundation
import MapKit

struct FoodSpot: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let detail: String
    let location: GeoPoint

    func distance(from location: GeoPoint) -> CLLocationDistance {
        CLLocation(latitude: self.location.latitude, longitude: self.location.longitude)
            .distance(from: CLLocation(latitude: location.latitude, longitude: location.longitude))
    }
}

@MainActor
final class NearbyFoodProvider: ObservableObject {
    @Published private(set) var spots: [FoodSpot] = []
    @Published private(set) var isSearching = false

    private var searchTask: Task<Void, Never>?

    func update(for location: GeoPoint, radiusMeters: CLLocationDistance) {
        searchTask?.cancel()

        // Show useful options immediately while MapKit looks up live restaurants.
        spots = Self.fallbackSpots(near: location, radiusMeters: radiusMeters)

        isSearching = true
        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(450))
                try Task.checkCancellation()
                let liveSpots = try await Self.searchMapKit(
                    near: location,
                    radiusMeters: radiusMeters
                )
                try Task.checkCancellation()

                guard let self else { return }
                if !liveSpots.isEmpty {
                    spots = liveSpots
                }
                isSearching = false
            } catch is CancellationError {
                // A newer location will start the next search.
            } catch {
                self?.isSearching = false
            }
        }
    }

    private static func searchMapKit(
        near location: GeoPoint,
        radiusMeters: CLLocationDistance
    ) async throws -> [FoodSpot] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "restaurants"
        request.resultTypes = .pointOfInterest

        let latitudeRadius = radiusMeters / 111_000
        let longitudeRadius = latitudeRadius / max(
            cos(location.latitude * .pi / 180),
            0.2
        )
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: latitudeRadius * 2,
                longitudeDelta: longitudeRadius * 2
            )
        )

        let response = try await MKLocalSearch(request: request).start()

        return response.mapItems
            .compactMap { mapItem -> FoodSpot? in
                guard let name = mapItem.name, !name.isEmpty else { return nil }

                let coordinate = mapItem.placemark.coordinate
                let point = GeoPoint(
                    longitude: coordinate.longitude,
                    latitude: coordinate.latitude
                )
                let locality = mapItem.placemark.locality ?? mapItem.placemark.subLocality
                let detail = locality.map { "Restaurant • \($0)" } ?? "Nearby restaurant"

                return FoodSpot(
                    id: stableID(name: name, location: point),
                    name: name,
                    detail: detail,
                    location: point
                )
            }
            .reduce(into: [String: FoodSpot]()) { results, spot in
                results[spot.id] = spot
            }
            .values
            .filter { $0.distance(from: location) <= radiusMeters }
            .sorted { $0.distance(from: location) < $1.distance(from: location) }
            .prefix(10)
            .map { $0 }
    }

    private static func stableID(name: String, location: GeoPoint) -> String {
        let latitude = Int((location.latitude * 100_000).rounded())
        let longitude = Int((location.longitude * 100_000).rounded())
        return "mapkit-\(name.lowercased())-\(latitude)-\(longitude)"
    }

    private static func fallbackSpots(
        near location: GeoPoint,
        radiusMeters: CLLocationDistance
    ) -> [FoodSpot] {
        let sorted = fallbackSpots.sorted {
            $0.distance(from: location) < $1.distance(from: location)
        }
        let localSpots = sorted.filter { $0.distance(from: location) <= radiusMeters }

        return Array(localSpots.prefix(8))
    }

    private static let fallbackSpots: [FoodSpot] = [
        FoodSpot(id: "tokyo-harajuku-ramen", name: "Harajuku Ramen", detail: "Ramen • Harajuku", location: GeoPoint(longitude: 139.7040, latitude: 35.6698)),
        FoodSpot(id: "tokyo-omotesando-sushi", name: "Omotesando Sushi", detail: "Sushi • Aoyama", location: GeoPoint(longitude: 139.7103, latitude: 35.6654)),
        FoodSpot(id: "tokyo-shibuya-yakitori", name: "Shibuya Yakitori", detail: "Yakitori • Shibuya", location: GeoPoint(longitude: 139.6993, latitude: 35.6587)),
        FoodSpot(id: "tokyo-meiji-cafe", name: "Meiji Garden Café", detail: "Café • Yoyogi", location: GeoPoint(longitude: 139.6948, latitude: 35.6748)),
        FoodSpot(id: "tokyo-shinjuku-udon", name: "Shinjuku Udon", detail: "Udon • Shinjuku", location: GeoPoint(longitude: 139.7006, latitude: 35.6901)),
        FoodSpot(id: "kyoto-gion-soba", name: "Gion Soba House", detail: "Soba • Gion", location: GeoPoint(longitude: 135.7754, latitude: 35.0037)),
        FoodSpot(id: "kyoto-nishiki-donburi", name: "Nishiki Donburi", detail: "Donburi • Nishiki Market", location: GeoPoint(longitude: 135.7649, latitude: 35.0050)),
        FoodSpot(id: "kyoto-pontocho-yakitori", name: "Pontocho Yakitori", detail: "Yakitori • Pontocho", location: GeoPoint(longitude: 135.7712, latitude: 35.0077)),
        FoodSpot(id: "kyoto-imperial-matcha", name: "Imperial Matcha Café", detail: "Café • Kamigyo", location: GeoPoint(longitude: 135.7620, latitude: 35.0240)),
        FoodSpot(id: "kyoto-higashiyama-tofu", name: "Higashiyama Tofu", detail: "Tofu • Higashiyama", location: GeoPoint(longitude: 135.7811, latitude: 35.0094)),
        FoodSpot(id: "osaka-dotonbori-takoyaki", name: "Dotonbori Takoyaki", detail: "Takoyaki • Dotonbori", location: GeoPoint(longitude: 135.5015, latitude: 34.6687)),
        FoodSpot(id: "osaka-namba-okonomiyaki", name: "Namba Okonomiyaki", detail: "Okonomiyaki • Namba", location: GeoPoint(longitude: 135.5019, latitude: 34.6662)),
        FoodSpot(id: "osaka-kuromon-grill", name: "Kuromon Market Grill", detail: "Seafood • Nipponbashi", location: GeoPoint(longitude: 135.5065, latitude: 34.6654)),
        FoodSpot(id: "osaka-umeda-kushikatsu", name: "Umeda Kushikatsu", detail: "Kushikatsu • Umeda", location: GeoPoint(longitude: 135.4983, latitude: 34.7032))
    ]
}

@MainActor
final class SavedFoodStore: ObservableObject {
    @Published private(set) var spots: [FoodSpot]

    private let defaultsKey = "savedFoodSpots"
    private let resetVersionKey = "savedFoodSpotsResetVersion"
    private let currentResetVersion = 1

    init() {
        let defaults = UserDefaults.standard

        if defaults.integer(forKey: resetVersionKey) < currentResetVersion {
            defaults.removeObject(forKey: defaultsKey)
            defaults.set(currentResetVersion, forKey: resetVersionKey)
        }

        guard
            let data = defaults.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode([FoodSpot].self, from: data)
        else {
            spots = []
            return
        }

        spots = decoded
    }

    func contains(_ spot: FoodSpot) -> Bool {
        spots.contains { $0.id == spot.id }
    }

    func toggle(_ spot: FoodSpot) {
        if let index = spots.firstIndex(where: { $0.id == spot.id }) {
            spots.remove(at: index)
        } else {
            spots.append(spot)
        }

        if let data = try? JSONEncoder().encode(spots) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
