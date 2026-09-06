//
//  SpotMapView.swift
//  Spotit
//

import MapKit
import SwiftUI

struct SpotMapView: View {
    @State private var selectedDestinationID: String?
    @State private var selectedRecommendationID: String?
    @State private var showsRecommendations = true
    @State private var cameraPosition: MapCameraPosition = .region(Self.harajukuRegion)
    @State private var visibleRegion = Self.harajukuRegion
    @State private var selectedRadius: RecommendationRadius = .oneKilometer
    @State private var selectedFoodSpot: FoodSpot?
    @StateObject private var locationProvider = LocationProvider(simulatesHarajuku: true)
    @StateObject private var nearbyFoodProvider = NearbyFoodProvider()
    @StateObject private var savedFoodStore = SavedFoodStore()

    private var nearYouRecommendations: [RankedFoodSpot] {
        nearbyFoodProvider.sections.first(where: { $0.kind == .nearYou })?.items ?? []
    }

    private var worthTheWalkIDs: Set<String> {
        Set(
            nearbyFoodProvider.sections
                .first(where: { $0.kind == .worthTheWalk })?
                .items
                .map(\.id) ?? []
        )
    }

    private var nearbyRecommendationIDs: Set<String> {
        Set(nearYouRecommendations.map(\.id))
    }

    private var selectedRecommendation: RankedFoodSpot? {
        nearYouRecommendations.first { $0.id == selectedRecommendationID }
    }

    private var isUsingTestLocation: Bool { locationProvider.isSimulatingLocation }

    var body: some View {
        GeometryReader { geometry in
            let panelHeight = min(max(geometry.size.height * 0.35, 280), 340)

            ZStack(alignment: .bottom) {
                spotitMap
                mapControls(panelHeight: panelHeight)

                if showsRecommendations {
                    recommendationPanel
                        .frame(height: panelHeight)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(SpotitStyle.warmBackground)
        .onAppear {
            locationProvider.start()
            guard let location = locationProvider.location else { return }
            nearbyFoodProvider.update(for: location, radiusMeters: selectedRadius.meters)
            focusOnDiscoveryRadius(animated: false)
        }
        .onChange(of: locationProvider.location) { _, location in
            guard let location else { return }
            nearbyFoodProvider.update(for: location, radiusMeters: selectedRadius.meters)
        }
        .onChange(of: selectedRadius) { _, radius in
            guard let location = locationProvider.location else { return }
            nearbyFoodProvider.update(for: location, radiusMeters: radius.meters)
            selectedRecommendationID = nil
            focusOnDiscoveryRadius()
        }
        .onChange(of: nearYouRecommendations.map(\.id)) { _, ids in
            guard !ids.isEmpty else {
                selectedRecommendationID = nil
                return
            }
            if selectedRecommendationID.map({ !ids.contains($0) }) ?? true {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    selectedRecommendationID = ids.first
                }
            }
        }
        .sheet(item: $selectedFoodSpot) { spot in
            FoodSpotDetailView(
                spot: spot,
                userLocation: locationProvider.location,
                isWorthTheWalk: worthTheWalkIDs.contains(spot.id),
                isSaved: savedFoodStore.contains(spot),
                toggleSaved: { savedFoodStore.toggle(spot) }
            )
        }
    }

    private var recommendationPanel: some View {
        RecommendationPanel(
            recommendations: nearYouRecommendations,
            selectedID: selectedRecommendationID,
            worthTheWalkIDs: worthTheWalkIDs,
            radiusDescription: "Within a \(selectedRadius.walkingMinuteCount) minute walk · curated nearby",
            isLoading: nearbyFoodProvider.isSearching,
            isSaved: savedFoodStore.contains,
            select: selectRecommendation,
            open: { recommendation in
                selectedRecommendationID = recommendation.id
                selectedFoodSpot = recommendation.spot
            },
            toggleSaved: savedFoodStore.toggle
        ) {
            radiusMenuLabel
        }
    }

    private var radiusMenuLabel: some View {
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
            Text("FILTER")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(SpotitStyle.purple)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter recommendation radius")
        .accessibilityValue(selectedRadius.title)
    }

    private func mapControls(panelHeight: CGFloat) -> some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    Button(action: { focusOnDiscoveryRadius() }) {
                        MapControlButton(
                            systemImage: "location.fill",
                            accessibilityLabel: isUsingTestLocation ? "Center testing location" : "Center current location"
                        )
                    }
                    .buttonStyle(.plain)

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
                        MapControlButton(
                            systemImage: "circle.dashed",
                            accessibilityLabel: "Change discovery radius"
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            HStack {
                Spacer()
                Button(action: showJapanOverview) {
                    MapControlButton(
                        systemImage: "globe.asia.australia.fill",
                        accessibilityLabel: "Explore Japan"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, showsRecommendations ? panelHeight + 14 : 20)
        }
        .animation(.smooth(duration: 0.3), value: showsRecommendations)
    }

    private var spotitMap: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
                if let userLocation = locationProvider.location {
                    MapCircle(center: userLocation.coordinate, radius: selectedRadius.meters)
                        .foregroundStyle(SpotitStyle.purple.opacity(0.045))
                    MapCircle(center: userLocation.coordinate, radius: selectedRadius.meters)
                        .foregroundStyle(.clear)
                        .stroke(
                            SpotitStyle.purple.opacity(0.72),
                            style: StrokeStyle(lineWidth: 1.8, dash: [7, 6])
                        )
                }

                ForEach(nearYouRecommendations.filter { $0.id != selectedRecommendationID }) { recommendation in
                    Annotation(
                        recommendation.spot.name,
                        coordinate: recommendation.spot.location.coordinate,
                        anchor: .center
                    ) {
                        Button {
                            selectRecommendation(recommendation)
                        } label: {
                            MapRecommendationAnnotation(
                                symbolName: recommendation.spot.category.symbolName,
                                isSelected: false,
                                isSaved: savedFoodStore.contains(recommendation.spot)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Selects this recommendation")
                    }
                    .annotationTitles(.hidden)
                }

                if let recommendation = selectedRecommendation {
                    Annotation(
                        recommendation.spot.name,
                        coordinate: recommendation.spot.location.coordinate,
                        anchor: .center
                    ) {
                        Button {
                            selectRecommendation(recommendation)
                        } label: {
                            MapRecommendationAnnotation(
                                symbolName: recommendation.spot.category.symbolName,
                                isSelected: true,
                                isSaved: savedFoodStore.contains(recommendation.spot)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Selected recommendation")
                    }
                    .annotationTitles(.hidden)
                }

                ForEach(savedFoodStore.spots.filter { !nearbyRecommendationIDs.contains($0.id) }) { spot in
                    Annotation(spot.name, coordinate: spot.location.coordinate, anchor: .center) {
                        Button { selectedFoodSpot = spot } label: {
                            MapRecommendationAnnotation(
                                symbolName: "heart.fill",
                                isSelected: false,
                                isSaved: true
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens saved place details")
                    }
                    .annotationTitles(.hidden)
                }

                if let userLocation = locationProvider.location {
                    Annotation(
                        isUsingTestLocation ? "Testing location" : "Your location",
                        coordinate: userLocation.coordinate,
                        anchor: .center
                    ) {
                        UserLocationMarker(isDraggable: isUsingTestLocation) { translation in
                            moveTestingLocation(by: translation, from: userLocation, using: proxy)
                        }
                    }
                    .annotationTitles(.hidden)
                }

                if isShowingNationalOverview {
                    ForEach(Self.destinations) { destination in
                        Annotation(destination.name, coordinate: destination.location.coordinate) {
                            Button {
                                selectedDestinationID = destination.id
                                focus(on: destination)
                            } label: {
                                MapRecommendationAnnotation(
                                    symbolName: "building.2.fill",
                                    isSelected: destination.id == selectedDestinationID
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .mapStyle(
                .standard(
                    elevation: .flat,
                    emphasis: .muted,
                    pointsOfInterest: .excludingAll,
                    showsTraffic: false
                )
            )
            .mapControls { MapCompass() }
            .coordinateSpace(name: "spotitMap")
            .highPriorityGesture(
                SpatialTapGesture(count: 2, coordinateSpace: .named("spotitMap"))
                    .onEnded { value in
                        let coordinate = proxy.convert(value.location, from: .named("spotitMap"))
                        zoom(by: 0.48, around: coordinate)
                    }
            )
            .onMapCameraChange(frequency: .continuous) { context in
                visibleRegion = context.region
                let isLocal = max(context.region.span.latitudeDelta, context.region.span.longitudeDelta) < 0.45
                guard isLocal != showsRecommendations else { return }
                withAnimation(.smooth(duration: 0.3)) { showsRecommendations = isLocal }
            }
        }
        .ignoresSafeArea()
    }

    private var isShowingNationalOverview: Bool {
        max(visibleRegion.span.latitudeDelta, visibleRegion.span.longitudeDelta) > 2.5
    }

    private func selectRecommendation(_ recommendation: RankedFoodSpot) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            selectedRecommendationID = recommendation.id
        }
        focus(on: recommendation)
    }

    private func focusOnDiscoveryRadius(animated: Bool = true) {
        guard let location = locationProvider.location else { return }

        let latitudeRadius = selectedRadius.meters / 111_000
        let longitudeRadius = latitudeRadius / max(cos(location.latitude * .pi / 180), 0.2)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: location.latitude - latitudeRadius * 0.30,
                longitude: location.longitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(latitudeRadius * 2.75, 0.006),
                longitudeDelta: max(longitudeRadius * 2.75, 0.006)
            )
        )

        selectedDestinationID = nil
        if animated {
            withAnimation(.smooth(duration: 0.62)) { cameraPosition = .region(region) }
        } else {
            cameraPosition = .region(region)
        }
    }

    private func focus(on recommendation: RankedFoodSpot) {
        guard let userLocation = locationProvider.location else { return }

        let spot = recommendation.spot.location
        let latitudeDifference = abs(spot.latitude - userLocation.latitude)
        let longitudeDifference = abs(spot.longitude - userLocation.longitude)
        let latitudeSpan = max(latitudeDifference * 2.8, 0.006)
        let longitudeSpan = max(longitudeDifference * 2.8, 0.006)
        let center = CLLocationCoordinate2D(
            latitude: (spot.latitude + userLocation.latitude) / 2 - latitudeSpan * 0.10,
            longitude: (spot.longitude + userLocation.longitude) / 2
        )

        withAnimation(.smooth(duration: 0.42)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: latitudeSpan, longitudeDelta: longitudeSpan)
                )
            )
        }
    }

    private func moveTestingLocation(
        by translation: CGSize,
        from location: GeoPoint,
        using proxy: MapProxy
    ) {
        guard isUsingTestLocation,
              let anchorPoint = proxy.convert(location.coordinate, to: .named("spotitMap"))
        else { return }

        let droppedAnchor = CGPoint(
            x: anchorPoint.x + translation.width,
            y: anchorPoint.y + translation.height
        )
        guard let coordinate = proxy.convert(droppedAnchor, from: .named("spotitMap")) else { return }

        locationProvider.moveSimulatedLocation(
            to: GeoPoint(longitude: coordinate.longitude, latitude: coordinate.latitude)
        )
    }

    private func zoom(by factor: Double, around center: CLLocationCoordinate2D? = nil) {
        let latitudeDelta = min(max(visibleRegion.span.latitudeDelta * factor, 0.002), 80)
        let longitudeDelta = min(max(visibleRegion.span.longitudeDelta * factor, 0.002), 180)
        let region = MKCoordinateRegion(
            center: center ?? visibleRegion.center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
        withAnimation(.smooth(duration: 0.35)) { cameraPosition = .region(region) }
    }

    private func showJapanOverview() {
        selectedRecommendationID = nil
        withAnimation(.smooth(duration: 0.72)) { cameraPosition = .region(Self.destinationsRegion) }
    }

    private func focus(on destination: Destination) {
        withAnimation(.smooth(duration: 0.72)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: destination.location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.13, longitudeDelta: 0.15)
                )
            )
        }
    }

    private static let destinations = [
        Destination(name: "Tokyo", location: GeoPoint(longitude: 139.6503, latitude: 35.6762)),
        Destination(name: "Kyoto", location: GeoPoint(longitude: 135.7681, latitude: 35.0116)),
        Destination(name: "Osaka", location: GeoPoint(longitude: 135.5023, latitude: 34.6937))
    ]

    private static let harajukuRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6675, longitude: 139.7027),
        span: MKCoordinateSpan(latitudeDelta: 0.026, longitudeDelta: 0.032)
    )

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

    var walkingMinuteCount: Int { max(1, Int(ceil(meters / 80))) }
    var walkingTime: String { "~\(walkingMinuteCount) min walk" }
    var title: String { "\(shortTitle) · \(walkingTime)" }
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
