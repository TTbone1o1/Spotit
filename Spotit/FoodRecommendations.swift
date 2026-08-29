//
//  FoodRecommendations.swift
//  Spotit
//

import CoreLocation
import Foundation
import MapKit

enum FoodCategory: String, Codable, CaseIterable, Hashable {
    case ramen
    case sushi
    case yakitori
    case izakaya
    case curry
    case udon
    case soba
    case tonkatsu
    case yakiniku
    case tempura
    case kaiseki
    case cafe
    case desserts
    case streetFood
    case convenience
    case japanese
    case restaurant

    var title: String {
        switch self {
        case .ramen: "Ramen"
        case .sushi: "Sushi"
        case .yakitori: "Yakitori"
        case .izakaya: "Izakaya"
        case .curry: "Curry"
        case .udon: "Udon"
        case .soba: "Soba"
        case .tonkatsu: "Tonkatsu"
        case .yakiniku: "Yakiniku"
        case .tempura: "Tempura"
        case .kaiseki: "Kaiseki"
        case .cafe: "Cafe"
        case .desserts: "Desserts"
        case .streetFood: "Street food"
        case .convenience: "Quick food"
        case .japanese: "Japanese"
        case .restaurant: "Restaurant"
        }
    }

    var symbolName: String {
        switch self {
        case .cafe: "cup.and.saucer.fill"
        case .desserts: "birthday.cake.fill"
        case .streetFood, .convenience: "takeoutbag.and.cup.and.straw.fill"
        default: "fork.knife"
        }
    }

    var isJapaneseFavorite: Bool {
        ![.cafe, .desserts, .convenience, .restaurant].contains(self)
    }

    var isQuickBite: Bool {
        [.cafe, .desserts, .streetFood, .convenience, .curry, .udon, .soba].contains(self)
    }
}

struct FoodSpot: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: FoodCategory
    let location: GeoPoint
    let neighborhood: String?
    let rating: Double?
    let reviewCount: Int?
    let isOpen: Bool?
    let priceLevel: Int?
    let popularity: Double?
    let imageURLs: [URL]
    let address: String?
    let openingHours: [String]
    let summary: String?
    let phoneNumber: String?
    let websiteURL: URL?

    init(
        id: String,
        name: String,
        category: FoodCategory,
        location: GeoPoint,
        neighborhood: String? = nil,
        rating: Double? = nil,
        reviewCount: Int? = nil,
        isOpen: Bool? = nil,
        priceLevel: Int? = nil,
        popularity: Double? = nil,
        imageURLs: [URL] = [],
        address: String? = nil,
        openingHours: [String] = [],
        summary: String? = nil,
        phoneNumber: String? = nil,
        websiteURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.location = location
        self.neighborhood = neighborhood
        self.rating = rating
        self.reviewCount = reviewCount
        self.isOpen = isOpen
        self.priceLevel = priceLevel
        self.popularity = popularity
        self.imageURLs = imageURLs
        self.address = address
        self.openingHours = openingHours
        self.summary = summary
        self.phoneNumber = phoneNumber
        self.websiteURL = websiteURL
    }

    var detail: String {
        if let neighborhood, !neighborhood.isEmpty {
            return "\(category.title) • \(neighborhood)"
        }
        return category.title
    }

    func distance(from location: GeoPoint) -> CLLocationDistance {
        CLLocation(latitude: self.location.latitude, longitude: self.location.longitude)
            .distance(from: CLLocation(latitude: location.latitude, longitude: location.longitude))
    }
}

@MainActor
final class NearbyFoodProvider: ObservableObject {
    @Published private(set) var spots: [FoodSpot] = []
    @Published private(set) var sections: [FoodRecommendationSection] = []
    @Published private(set) var isSearching = false

    private let recommendationService: FoodRecommendationService
    private var candidates: [FoodSpot]
    private var searchTask: Task<Void, Never>?
    private var lastSearchLocation: GeoPoint?
    private var lastSearchRadius: CLLocationDistance?

    init(recommendationService: FoodRecommendationService = FoodRecommendationService()) {
        self.recommendationService = recommendationService
        candidates = NearbyFoodProvider.fallbackSpots
    }

    func update(for location: GeoPoint, radiusMeters: CLLocationDistance) {
        searchTask?.cancel()
        publishRecommendations(near: location, radiusMeters: radiusMeters)

        let movementSinceSearch = lastSearchLocation?.distance(from: location) ?? .greatestFiniteMagnitude
        let refreshDistance = max(40, min(radiusMeters * 0.10, 150))
        let radiusChanged = lastSearchRadius.map { abs($0 - radiusMeters) > 1 } ?? true
        let needsSearch = radiusChanged || movementSinceSearch >= refreshDistance

        guard needsSearch else {
            isSearching = false
            return
        }

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
                candidates = Self.merge(liveSpots, with: Self.fallbackSpots)
                lastSearchLocation = location
                lastSearchRadius = radiusMeters
                publishRecommendations(near: location, radiusMeters: radiusMeters)
                isSearching = false
            } catch is CancellationError {
                // The latest location/radius update owns the next search.
            } catch {
                self?.lastSearchLocation = location
                self?.lastSearchRadius = radiusMeters
                self?.isSearching = false
            }
        }
    }

    private func publishRecommendations(
        near location: GeoPoint,
        radiusMeters: CLLocationDistance
    ) {
        sections = recommendationService.recommendations(
            from: candidates,
            near: location,
            radiusMeters: radiusMeters
        )
        spots = sections.first(where: { $0.kind == .nearYou })?.items.map(\.spot) ?? []
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

        return response.mapItems.compactMap { mapItem -> FoodSpot? in
            guard let name = mapItem.name, !name.isEmpty else { return nil }

            let coordinate = mapItem.placemark.coordinate
            let point = GeoPoint(
                longitude: coordinate.longitude,
                latitude: coordinate.latitude
            )
            let locality = mapItem.placemark.subLocality ?? mapItem.placemark.locality
            let category = FoodCategory.infer(
                name: name,
                pointOfInterestCategory: mapItem.pointOfInterestCategory
            )

            return FoodSpot(
                id: stableID(name: name, location: point),
                name: name,
                category: category,
                location: point,
                neighborhood: locality,
                address: mapItem.placemark.title,
                summary: "A nearby \(category.title.lowercased()) spot found with Apple Maps.",
                phoneNumber: mapItem.phoneNumber,
                websiteURL: mapItem.url
            )
        }
    }

    private static func stableID(name: String, location: GeoPoint) -> String {
        let latitude = Int((location.latitude * 100_000).rounded())
        let longitude = Int((location.longitude * 100_000).rounded())
        return "mapkit-\(name.lowercased())-\(latitude)-\(longitude)"
    }

    private static func merge(_ primary: [FoodSpot], with secondary: [FoodSpot]) -> [FoodSpot] {
        (primary + secondary).reduce(into: [String: FoodSpot]()) { result, spot in
            result[spot.id] = spot
        }.values.map { $0 }
    }

    private static let fallbackSpots: [FoodSpot] = [
        FoodSpot(id: "tokyo-harajuku-ramen", name: "Harajuku Ramen", category: .ramen, location: GeoPoint(longitude: 139.7040, latitude: 35.6698), neighborhood: "Harajuku"),
        FoodSpot(id: "tokyo-omotesando-sushi", name: "Omotesando Sushi", category: .sushi, location: GeoPoint(longitude: 139.7103, latitude: 35.6654), neighborhood: "Aoyama"),
        FoodSpot(id: "tokyo-shibuya-yakitori", name: "Shibuya Yakitori", category: .yakitori, location: GeoPoint(longitude: 139.6993, latitude: 35.6587), neighborhood: "Shibuya"),
        FoodSpot(id: "tokyo-meiji-cafe", name: "Meiji Garden Café", category: .cafe, location: GeoPoint(longitude: 139.6948, latitude: 35.6748), neighborhood: "Yoyogi"),
        FoodSpot(id: "tokyo-shinjuku-udon", name: "Shinjuku Udon", category: .udon, location: GeoPoint(longitude: 139.7006, latitude: 35.6901), neighborhood: "Shinjuku"),
        FoodSpot(id: "kyoto-gion-soba", name: "Gion Soba House", category: .soba, location: GeoPoint(longitude: 135.7754, latitude: 35.0037), neighborhood: "Gion"),
        FoodSpot(id: "kyoto-nishiki-donburi", name: "Nishiki Donburi", category: .japanese, location: GeoPoint(longitude: 135.7649, latitude: 35.0050), neighborhood: "Nishiki Market"),
        FoodSpot(id: "kyoto-pontocho-yakitori", name: "Pontocho Yakitori", category: .yakitori, location: GeoPoint(longitude: 135.7712, latitude: 35.0077), neighborhood: "Pontocho"),
        FoodSpot(id: "kyoto-imperial-matcha", name: "Imperial Matcha Café", category: .cafe, location: GeoPoint(longitude: 135.7620, latitude: 35.0240), neighborhood: "Kamigyo"),
        FoodSpot(id: "kyoto-higashiyama-tofu", name: "Higashiyama Tofu", category: .kaiseki, location: GeoPoint(longitude: 135.7811, latitude: 35.0094), neighborhood: "Higashiyama"),
        FoodSpot(id: "osaka-dotonbori-takoyaki", name: "Dotonbori Takoyaki", category: .streetFood, location: GeoPoint(longitude: 135.5015, latitude: 34.6687), neighborhood: "Dotonbori"),
        FoodSpot(id: "osaka-namba-okonomiyaki", name: "Namba Okonomiyaki", category: .japanese, location: GeoPoint(longitude: 135.5019, latitude: 34.6662), neighborhood: "Namba"),
        FoodSpot(id: "osaka-kuromon-grill", name: "Kuromon Market Grill", category: .streetFood, location: GeoPoint(longitude: 135.5065, latitude: 34.6654), neighborhood: "Nipponbashi"),
        FoodSpot(id: "osaka-umeda-kushikatsu", name: "Umeda Kushikatsu", category: .izakaya, location: GeoPoint(longitude: 135.4983, latitude: 34.7032), neighborhood: "Umeda")
    ]
}

private extension FoodCategory {
    static func infer(
        name: String,
        pointOfInterestCategory: MKPointOfInterestCategory?
    ) -> FoodCategory {
        let value = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        let matches: [(FoodCategory, [String])] = [
            (.ramen, ["ramen", "ラーメン", "らーめん"]),
            (.sushi, ["sushi", "鮨", "寿司"]),
            (.yakitori, ["yakitori", "焼鳥", "焼き鳥"]),
            (.izakaya, ["izakaya", "居酒屋"]),
            (.curry, ["curry", "カレー"]),
            (.udon, ["udon", "うどん"]),
            (.soba, ["soba", "そば", "蕎麦"]),
            (.tonkatsu, ["tonkatsu", "とんかつ", "豚カツ"]),
            (.yakiniku, ["yakiniku", "焼肉"]),
            (.tempura, ["tempura", "天ぷら", "天麩羅"]),
            (.kaiseki, ["kaiseki", "懐石", "割烹"]),
            (.desserts, ["dessert", "sweets", "patisserie", "ケーキ", "スイーツ"]),
            (.cafe, ["cafe", "coffee", "café", "喫茶", "珈琲"]),
            (.streetFood, ["takoyaki", "たこ焼", "okonomiyaki", "お好み焼"]),
            (.convenience, ["7-eleven", "familymart", "lawson", "コンビニ"])
        ]

        if let match = matches.first(where: { _, keywords in
            keywords.contains { value.contains($0.lowercased()) }
        }) {
            return match.0
        }

        if pointOfInterestCategory == .cafe || pointOfInterestCategory == .bakery {
            return .cafe
        }
        return .restaurant
    }
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
