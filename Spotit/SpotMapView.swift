//
//  SpotMapView.swift
//  Spotit
//
//  Created by Abraham May on 7/9/26.
//

import MapKit
import SwiftUI

struct SpotMapView: View {
    @State private var selectedDestinationID: String?
    @State private var showsRecommendations = false
    @State private var cameraPosition: MapCameraPosition = .region(Self.destinationsRegion)
    @State private var visibleRegion = Self.destinationsRegion
    @State private var selectedRadius: RecommendationRadius = .oneKilometer
    @State private var selectedFoodSpot: FoodSpot?
    @StateObject private var locationProvider = LocationProvider(simulatesHarajuku: true)
    @StateObject private var nearbyFoodProvider = NearbyFoodProvider()
    @StateObject private var savedFoodStore = SavedFoodStore()

    private var selectedDestination: Destination? {
        Self.destinations.first { $0.id == selectedDestinationID }
    }

    private var nearbyAreaName: String {
        guard let location = locationProvider.location else { return "your location" }

        return Self.destinations.min {
            $0.location.distance(from: location) < $1.location.distance(from: location)
        }?.name ?? "your location"
    }

    private var nearYouRecommendations: [RankedFoodSpot] {
        nearbyFoodProvider.sections.first(where: { $0.kind == .nearYou })?.items ?? []
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            regularMap

            Button(action: focusOnTestingLocation) {
                Label("Find dot", systemImage: "location.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .overlay {
                        Capsule().stroke(.purple.opacity(0.5), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding()
            .accessibilityHint("Centers the map on the purple testing location")

            VStack(alignment: .trailing, spacing: 10) {
                rangeSelector

                if selectedDestination != nil {
                    Button {
                        withAnimation(.smooth(duration: 0.85)) {
                            selectedDestinationID = nil
                        }
                    } label: {
                        Label("All Japan", systemImage: "arrow.uturn.backward")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.white, in: Capsule())
                            .overlay {
                                Capsule().stroke(.black, lineWidth: 1.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()

            VStack {
                Spacer()

                if showsRecommendations {
                    recommendationShelf
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .preferredColorScheme(.light)
        .onChange(of: selectedDestinationID) { _, destinationID in
            updateMapCamera(for: destinationID)
        }
        .onAppear {
            locationProvider.start()
            if let location = locationProvider.location {
                nearbyFoodProvider.update(for: location, radiusMeters: selectedRadius.meters)
            }
        }
        .onChange(of: locationProvider.location) { _, location in
            if let location {
                nearbyFoodProvider.update(for: location, radiusMeters: selectedRadius.meters)
            }
        }
        .onChange(of: selectedRadius) { _, radius in
            if let location = locationProvider.location {
                nearbyFoodProvider.update(for: location, radiusMeters: radius.meters)
            }
        }
        .sheet(item: $selectedFoodSpot) { spot in
            FoodSpotDetailView(
                spot: spot,
                userLocation: locationProvider.location
            )
        }
    }

    private var rangeSelector: some View {
        Menu {
            ForEach(RecommendationRadius.allCases) { radius in
                Button {
                    selectedRadius = radius
                } label: {
                    if radius == selectedRadius {
                        Label(radius.title, systemImage: "checkmark")
                    } else {
                        Text(radius.title)
                    }
                }
            }
        } label: {
            Label(selectedRadius.shortTitle, systemImage: "circle.dashed")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .overlay {
                    Capsule().stroke(.purple.opacity(0.5), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Recommendation range, \(selectedRadius.title)")
    }

    private var recommendationShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Near You")
                        .font(.headline)
                    Text("Food near \(nearbyAreaName) • Within \(selectedRadius.shortTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if nearbyFoodProvider.isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Finding nearby food")
                }
            }
            .padding(.horizontal, 16)

            if nearYouRecommendations.isEmpty {
                ContentUnavailableView(
                    nearbyFoodProvider.isSearching ? "Finding nearby food" : "No food spots in range",
                    systemImage: "fork.knife.circle",
                    description: Text(
                        nearbyFoodProvider.isSearching
                            ? "Searching within \(selectedRadius.shortTitle)…"
                            : "Try a larger radius or move the purple location."
                    )
                )
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(nearYouRecommendations) { recommendation in
                            FoodRecommendationCard(
                                recommendation: recommendation,
                                isSaved: savedFoodStore.contains(recommendation.spot),
                                select: { selectedFoodSpot = recommendation.spot },
                                toggleSaved: { savedFoodStore.toggle(recommendation.spot) }
                            )
                            .containerRelativeFrame(.horizontal, count: 1, spacing: 12)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(height: 230)
        .background(.white.opacity(0.96))
        .clipShape(.rect(topLeadingRadius: 22, topTrailingRadius: 22))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
                .stroke(.black.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: -3)
    }

    private var regularMap: some View {
        MapReader { proxy in
            Map(
                position: $cameraPosition,
                interactionModes: [.pan, .zoom],
                selection: $selectedDestinationID
            ) {
                ForEach(Self.destinations) { destination in
                    Marker(
                        destination.name,
                        systemImage: "building.2.fill",
                        coordinate: destination.location.coordinate
                    )
                    .tint(.red)
                    .tag(destination.id)
                }

                if let testingLocation = locationProvider.location {
                    MapCircle(
                        center: testingLocation.coordinate,
                        radius: selectedRadius.meters
                    )
                    .foregroundStyle(.purple.opacity(0.30))

                    Annotation(
                        "Testing location",
                        coordinate: testingLocation.coordinate,
                        anchor: .center
                    ) {
                        TestingLocationMarker { translation in
                            guard let anchorPoint = proxy.convert(
                                testingLocation.coordinate,
                                to: .named("regularMap")
                            ) else { return }

                            // The marker is drawn at its annotation anchor plus the
                            // drag translation. Convert that exact visual anchor,
                            // rather than the finger's potentially offset location.
                            let droppedAnchor = CGPoint(
                                x: anchorPoint.x + translation.width,
                                y: anchorPoint.y + translation.height
                            )
                            guard let coordinate = proxy.convert(
                                droppedAnchor,
                                from: .named("regularMap")
                            ) else { return }

                            locationProvider.moveSimulatedLocation(
                                to: GeoPoint(
                                    longitude: coordinate.longitude,
                                    latitude: coordinate.latitude
                                )
                            )
                        }
                    }
                }

                ForEach(savedFoodStore.spots) { spot in
                    Marker(
                        spot.name,
                        systemImage: "heart.fill",
                        coordinate: spot.location.coordinate
                    )
                    .tint(.pink)
                }

            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .coordinateSpace(name: "regularMap")
            .highPriorityGesture(
                SpatialTapGesture(count: 2, coordinateSpace: .named("regularMap"))
                    .onEnded { value in
                        let coordinate = proxy.convert(
                            value.location,
                            from: .named("regularMap")
                        )
                        zoom(by: 0.45, around: coordinate)
                    }
            )
            .onMapCameraChange(frequency: .continuous) { context in
                visibleRegion = context.region

                let span = context.region.span
                let isCityLevel = max(span.latitudeDelta, span.longitudeDelta) < 6.0

                guard isCityLevel != showsRecommendations else { return }
                withAnimation(.smooth(duration: 0.3)) {
                    showsRecommendations = isCityLevel
                }
            }
        }
        .ignoresSafeArea()
    }

    private func focusOnTestingLocation() {
        guard let location = locationProvider.location else { return }

        let latitudeRadius = selectedRadius.meters / 111_000
        let longitudeRadius = latitudeRadius / max(
            cos(location.latitude * .pi / 180),
            0.2
        )
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: max(latitudeRadius * 2.6, 0.01),
                longitudeDelta: max(longitudeRadius * 2.6, 0.01)
            )
        )

        withAnimation(.smooth(duration: 0.65)) {
            cameraPosition = .region(region)
        }
    }

    private func zoom(by factor: Double, around center: CLLocationCoordinate2D? = nil) {
        let latitudeDelta = min(max(visibleRegion.span.latitudeDelta * factor, 0.002), 80)
        let longitudeDelta = min(max(visibleRegion.span.longitudeDelta * factor, 0.002), 180)
        let region = MKCoordinateRegion(
            center: center ?? visibleRegion.center,
            span: MKCoordinateSpan(
                latitudeDelta: latitudeDelta,
                longitudeDelta: longitudeDelta
            )
        )

        withAnimation(.smooth(duration: 0.35)) {
            cameraPosition = .region(region)
        }
    }

    private func updateMapCamera(for destinationID: String?) {
        let region: MKCoordinateRegion

        if let destination = Self.destinations.first(where: { $0.id == destinationID }) {
            region = MKCoordinateRegion(
                center: destination.location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.4)
            )
        } else {
            region = Self.destinationsRegion
        }

        withAnimation(.smooth(duration: 0.85)) {
            cameraPosition = .region(region)
        }
    }

    private static let destinations = [
        Destination(name: "Tokyo", location: GeoPoint(longitude: 139.6503, latitude: 35.6762)),
        Destination(name: "Kyoto", location: GeoPoint(longitude: 135.7681, latitude: 35.0116)),
        Destination(name: "Osaka", location: GeoPoint(longitude: 135.5023, latitude: 34.6937))
    ]

    private static let destinationsRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.5, longitude: 137.5),
        span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 17.0)
    )
}

private enum RecommendationRadius: String, CaseIterable, Identifiable {
    case veryClose
    case close
    case oneKilometer
    case oneAndHalfKilometers
    case twoKilometers
    case fiveKilometers

    var id: Self { self }

    var meters: CLLocationDistance {
        switch self {
        case .veryClose: 250
        case .close: 500
        case .oneKilometer: 1_000
        case .oneAndHalfKilometers: 1_500
        case .twoKilometers: 2_000
        case .fiveKilometers: 5_000
        }
    }

    var shortTitle: String {
        switch self {
        case .veryClose: "250 m"
        case .close: "500 m"
        case .oneKilometer: "1 km"
        case .oneAndHalfKilometers: "1.5 km"
        case .twoKilometers: "2 km"
        case .fiveKilometers: "5 km"
        }
    }

    var walkingTime: String {
        switch self {
        case .veryClose: "~3 min walk"
        case .close: "~6 min walk"
        case .oneKilometer: "~13 min walk"
        case .oneAndHalfKilometers: "~19 min walk"
        case .twoKilometers: "~25 min walk"
        case .fiveKilometers: "~63 min walk"
        }
    }

    var title: String { "\(shortTitle) • \(walkingTime)" }
}

private struct TestingLocationMarker: View {
    @GestureState private var isDragging = false
    @GestureState private var dragOffset: CGSize = .zero
    let moveByTranslation: (CGSize) -> Void

    var body: some View {
        Circle()
            .fill(.purple)
            .frame(width: 20, height: 20)
            .overlay {
                Circle().stroke(.white, lineWidth: 3)
            }
            .shadow(color: .black.opacity(0.28), radius: 3, y: 2)
        .frame(width: 48, height: 48)
        .contentShape(Circle())
        .offset(dragOffset)
        .scaleEffect(isDragging ? 1.18 : 1)
        .animation(.smooth(duration: 0.18), value: isDragging)
        .highPriorityGesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .named("regularMap"))
                .updating($isDragging) { _, state, _ in
                    state = true
                }
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    moveByTranslation(value.translation)
                }
        )
        .accessibilityLabel("Testing location")
        .accessibilityHint("Drag to change the location used for nearby food recommendations")
    }
}

private struct FoodRecommendationCard: View {
    let recommendation: RankedFoodSpot
    let isSaved: Bool
    let select: () -> Void
    let toggleSaved: () -> Void

    private var spot: FoodSpot { recommendation.spot }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: select) {
                HStack(spacing: 14) {
                    FoodSpotImageView(
                        spot: spot,
                        snapshotSize: CGSize(width: 384, height: 448)
                    )
                        .frame(width: 96, height: 112)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(spot.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        categoryAndRating

                        Text("\(distanceText) · ~\(recommendation.walkingMinutes) min walk")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.purple)

                        availability
                    }

                    Spacer(minLength: 42)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens restaurant details")

            Button(action: toggleSaved) {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSaved ? .pink : .black)
                    .frame(width: 42, height: 42)
                    .background(isSaved ? .pink.opacity(0.12) : .black.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityLabel(isSaved ? "Unlike \(spot.name)" : "Like \(spot.name)")
            .accessibilityHint(isSaved ? "Removes this spot from the map" : "Saves this spot on the map")
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.14), lineWidth: 1)
        }
    }

    private var categoryAndRating: some View {
        HStack(spacing: 5) {
            Text(spot.category.title)
            if let rating = spot.rating {
                Text("·")
                Label(
                    rating.formatted(.number.precision(.fractionLength(1))),
                    systemImage: "star.fill"
                )
            }
            if let reviewCount = spot.reviewCount {
                Text("(\(reviewCount.formatted(.number.notation(.compactName))))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    @ViewBuilder
    private var availability: some View {
        if spot.priceLevel != nil || spot.isOpen != nil {
            HStack(spacing: 8) {
                if let priceLevel = spot.priceLevel {
                    Text(String(repeating: "¥", count: min(max(priceLevel, 1), 4)))
                }
                if let isOpen = spot.isOpen {
                    Text(isOpen ? "Open" : "Closed")
                        .foregroundStyle(isOpen ? .green : .red)
                }
            }
            .font(.caption.weight(.semibold))
        }
    }

    private var distanceText: String {
        if recommendation.distance < 1_000 {
            return "\(Int((recommendation.distance / 10).rounded() * 10)) m"
        }
        return String(format: "%.1f km", recommendation.distance / 1_000)
    }
}

private struct Destination: Identifiable {
    let name: String
    let location: GeoPoint

    var id: String { name }
}

struct GeoPoint: Codable, Hashable {
    let longitude: Double
    let latitude: Double

    init(longitude: Double, latitude: Double) {
        self.longitude = longitude
        self.latitude = latitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(from other: GeoPoint) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}

#Preview {
    SpotMapView()
}
