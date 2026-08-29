//
//  FoodRecommendationService.swift
//  Spotit
//

import CoreLocation
import Foundation

struct FoodRecommendationWeights: Hashable {
    var distance = 0.32
    var rating = 0.30
    var reviewCount = 0.10
    var openNow = 0.08
    var category = 0.06
    var popularity = 0.14
    var repeatedCategoryPenalty = 0.14
    var repeatedNamePenalty = 0.10
}

enum FoodRecommendationSectionKind: String, Codable, Hashable {
    case nearYou
    case worthTheWalk
    case japaneseFavorites
    case hiddenGems
    case quickBite

    var title: String {
        switch self {
        case .nearYou: "Near You"
        case .worthTheWalk: "Worth the Walk"
        case .japaneseFavorites: "Japanese Favorites"
        case .hiddenGems: "Hidden Gems"
        case .quickBite: "Quick Bite"
        }
    }
}

struct RankedFoodSpot: Identifiable, Hashable {
    let spot: FoodSpot
    let distance: CLLocationDistance
    let score: Double

    var id: String { spot.id }

    var walkingMinutes: Int {
        max(1, Int(ceil(distance / 80)))
    }
}

struct FoodRecommendationSection: Identifiable, Hashable {
    let kind: FoodRecommendationSectionKind
    let items: [RankedFoodSpot]

    var id: FoodRecommendationSectionKind { kind }
    var title: String { kind.title }
}

struct FoodRecommendationService {
    var weights: FoodRecommendationWeights

    init(weights: FoodRecommendationWeights = FoodRecommendationWeights()) {
        self.weights = weights
    }

    func recommendations(
        from candidates: [FoodSpot],
        near userLocation: GeoPoint,
        radiusMeters: CLLocationDistance
    ) -> [FoodRecommendationSection] {
        guard radiusMeters > 0 else { return [] }

        let ranked = candidates.compactMap { spot -> RankedFoodSpot? in
            let distance = spot.distance(from: userLocation)
            guard distance <= radiusMeters else { return nil }

            return RankedFoodSpot(
                spot: spot,
                distance: distance,
                score: score(spot, distance: distance, radiusMeters: radiusMeters)
            )
        }
        .sorted { $0.score > $1.score }

        let nearYou = diversify(ranked, limit: 10)
        var sections = [FoodRecommendationSection(kind: .nearYou, items: nearYou)]

        appendSection(
            .worthTheWalk,
            items: ranked.filter {
                $0.distance >= radiusMeters * 0.45 && ($0.spot.rating ?? 0) >= 4.3
            },
            to: &sections
        )
        appendSection(
            .japaneseFavorites,
            items: ranked.filter { $0.spot.category.isJapaneseFavorite },
            to: &sections
        )
        appendSection(
            .hiddenGems,
            items: ranked.filter {
                guard let rating = $0.spot.rating, let reviews = $0.spot.reviewCount else {
                    return false
                }
                return rating >= 4.3 && reviews <= 300
            },
            to: &sections
        )
        appendSection(
            .quickBite,
            items: ranked.filter {
                $0.spot.category.isQuickBite || ($0.spot.priceLevel ?? .max) <= 1
            },
            to: &sections
        )

        return sections
    }

    func score(
        _ spot: FoodSpot,
        distance: CLLocationDistance,
        radiusMeters: CLLocationDistance
    ) -> Double {
        let distanceFraction = min(max(distance / radiusMeters, 0), 1)
        let distanceScore = 1 - pow(distanceFraction, 0.75)
        let ratingScore = spot.rating.map { clamp(($0 - 3) / 2) } ?? 0.50
        let reviewScore = spot.reviewCount.map {
            clamp(log10(Double(max($0, 0)) + 1) / 4)
        } ?? 0.35
        let openScore = spot.isOpen.map { $0 ? 1.0 : 0.0 } ?? 0.50
        let categoryScore = spot.category == .restaurant ? 0.45 : 1.0
        let popularityScore = spot.popularity.map(clamp) ?? (
            ratingScore * 0.60 + reviewScore * 0.40
        )

        return distanceScore * weights.distance
            + ratingScore * weights.rating
            + reviewScore * weights.reviewCount
            + openScore * weights.openNow
            + categoryScore * weights.category
            + popularityScore * weights.popularity
    }

    private func diversify(_ ranked: [RankedFoodSpot], limit: Int) -> [RankedFoodSpot] {
        var remaining = ranked
        var selected: [RankedFoodSpot] = []

        while !remaining.isEmpty && selected.count < limit {
            let bestIndex = remaining.indices.max { firstIndex, secondIndex in
                diversifiedScore(remaining[firstIndex], selected: selected)
                    < diversifiedScore(remaining[secondIndex], selected: selected)
            }!
            selected.append(remaining.remove(at: bestIndex))
        }

        return selected
    }

    private func diversifiedScore(
        _ candidate: RankedFoodSpot,
        selected: [RankedFoodSpot]
    ) -> Double {
        let categoryRepeats = selected.filter {
            $0.spot.category == candidate.spot.category
        }.count
        let nameRepeats = selected.filter {
            normalizedName($0.spot.name) == normalizedName(candidate.spot.name)
        }.count

        return candidate.score
            - Double(categoryRepeats) * weights.repeatedCategoryPenalty
            - Double(nameRepeats) * weights.repeatedNamePenalty
    }

    private func appendSection(
        _ kind: FoodRecommendationSectionKind,
        items: [RankedFoodSpot],
        to sections: inout [FoodRecommendationSection]
    ) {
        let diversified = diversify(items, limit: 10)
        guard !diversified.isEmpty else { return }
        sections.append(FoodRecommendationSection(kind: kind, items: diversified))
    }

    private func normalizedName(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .prefix(2)
            .joined(separator: " ")
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
