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
    @State private var selectedRadius: RecommendationRadius = .tenMinuteWalk
    @State private var selectedFoodSpot: FoodSpot?
    @State private var selectedTab: SpotitHomeTab = .discover
    @State private var searchText = ""
    @StateObject private var locationProvider = LocationProvider(simulatesHarajuku: true)
    @StateObject private var nearbyFoodProvider = NearbyFoodProvider()
    @StateObject private var savedFoodStore = SavedFoodStore()

    private var nearYouRecommendations: [RankedFoodSpot] {
        nearbyFoodProvider.sections.first(where: { $0.kind == .nearYou })?.items ?? []
    }

    private var savedRecommendations: [RankedFoodSpot] {
        savedFoodStore.spots.map { spot in
            let distance = locationProvider.location.map(spot.distance) ?? 0
            return RankedFoodSpot(spot: spot, distance: distance, score: spot.popularity ?? 0)
        }
        .sorted { $0.distance < $1.distance }
    }

    private var activeRecommendations: [RankedFoodSpot] {
        selectedTab == .discover ? nearYouRecommendations : savedRecommendations
    }

    private var visibleRecommendations: [RankedFoodSpot] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return activeRecommendations }

        return activeRecommendations.filter { recommendation in
            let spot = recommendation.spot
            return [spot.name, spot.category.title, spot.neighborhood ?? "", spot.summary ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var worthTheWalkIDs: Set<String> {
        Set(
            nearbyFoodProvider.sections
                .first(where: { $0.kind == .worthTheWalk })?
                .items
                .map(\.id) ?? []
        )
    }

    private var selectedRecommendation: RankedFoodSpot? {
        visibleRecommendations.first { $0.id == selectedRecommendationID }
    }

    private var isUsingTestLocation: Bool { locationProvider.isSimulatingLocation }

    private var outsideRadiusCount: Int {
        guard selectedTab == .discover && searchText.isEmpty else { return 0 }
        return nearbyFoodProvider.justOutsideRadiusCount
    }

    var body: some View {
        GeometryReader { geometry in
            let cardHeight = min(max(geometry.size.height * 0.39, 315), 350)

            ZStack {
                spotitMap
                topControls

                if showsRecommendations {
                    RecommendationCarousel(
                        recommendations: visibleRecommendations,
                        selectedID: $selectedRecommendationID,
                        worthTheWalkIDs: worthTheWalkIDs,
                        isLoading: selectedTab == .discover && nearbyFoodProvider.isSearching,
                        emptyTitle: selectedTab == .saved ? "Nothing saved yet." : "Nothing worth the detour yet.",
                        isSaved: savedFoodStore.contains,
                        open: openRecommendation,
                        toggleSaved: savedFoodStore.toggle
                    )
                    .frame(height: cardHeight)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                mapControls(cardHeight: cardHeight)
            }
        }
        .background(SpotitStyle.warmBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SpotitBottomTabBar(selection: $selectedTab)
        }
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
        .onChange(of: selectedTab) { _, _ in
            searchText = ""
            selectedRecommendationID = visibleRecommendations.first?.id
            if selectedTab == .discover { focusOnDiscoveryRadius() }
        }
        .onChange(of: visibleRecommendations.map(\.id)) { _, ids in
            guard !ids.isEmpty else {
                selectedRecommendationID = nil
                return
            }
            if selectedRecommendationID.map({ !ids.contains($0) }) ?? true {
                selectedRecommendationID = ids.first
            }
        }
        .onChange(of: selectedRecommendationID) { oldID, newID in
            guard oldID != nil,
                  let newID,
                  let recommendation = visibleRecommendations.first(where: { $0.id == newID })
            else { return }
            focus(on: recommendation)
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

    private var topControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                DiscoverSearchField(text: $searchText)

                Menu {
                    radiusOptions
                } label: {
                    WalkingRadiusLabel(minutes: selectedRadius.walkingMinuteCount)
                }
                .buttonStyle(.plain)
            }

            WorthYourTimeIndicator(
                count: visibleRecommendations.count,
                outsideCount: outsideRadiusCount
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var radiusOptions: some View {
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
    }

    private func mapControls(cardHeight: CGFloat) -> some View {
        VStack(spacing: 10) {
            Button(action: { focusOnDiscoveryRadius() }) {
                MapControlButton(
                    systemImage: "location.fill",
                    accessibilityLabel: isUsingTestLocation ? "Center testing location" : "Center current location"
                )
            }
            .buttonStyle(.plain)

            Button(action: showJapanOverview) {
                MapControlButton(
                    systemImage: "globe.asia.australia.fill",
                    accessibilityLabel: "Explore Japan"
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 16)
        .padding(.bottom, showsRecommendations ? cardHeight + 34 : 20)
        .animation(.smooth(duration: 0.3), value: showsRecommendations)
    }

    private var spotitMap: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
                if let userLocation = locationProvider.location {
                    MapCircle(center: userLocation.coordinate, radius: selectedRadius.meters)
                        .foregroundStyle(SpotitStyle.purple.opacity(0.035))
                    MapCircle(center: userLocation.coordinate, radius: selectedRadius.meters)
                        .foregroundStyle(.clear)
                        .stroke(
                            SpotitStyle.purple.opacity(0.76),
                            style: StrokeStyle(lineWidth: 1.8, dash: [6, 5])
                        )
                }

                ForEach(visibleRecommendations.filter { $0.id != selectedRecommendationID }) { recommendation in
                    Annotation(
                        recommendation.spot.name,
                        coordinate: recommendation.spot.location.coordinate,
                        anchor: .center
                    ) {
                        Button { selectedRecommendationID = recommendation.id } label: {
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
                        Button { openRecommendation(recommendation) } label: {
                            MapRecommendationAnnotation(
                                symbolName: recommendation.spot.category.symbolName,
                                isSelected: true,
                                isSaved: savedFoodStore.contains(recommendation.spot)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the selected recommendation")
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

    private func openRecommendation(_ recommendation: RankedFoodSpot) {
        selectedRecommendationID = recommendation.id
        selectedFoodSpot = recommendation.spot
    }

    private func focusOnDiscoveryRadius(animated: Bool = true) {
        guard let location = locationProvider.location else { return }

        let latitudeRadius = selectedRadius.meters / 111_000
        let longitudeRadius = latitudeRadius / max(cos(location.latitude * .pi / 180), 0.2)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: location.latitude - latitudeRadius * 0.18,
                longitude: location.longitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(latitudeRadius * 2.9, 0.006),
                longitudeDelta: max(longitudeRadius * 2.9, 0.006)
            )
        )

        selectedDestinationID = nil
        if animated {
            withAnimation(.smooth(duration: 0.56)) { cameraPosition = .region(region) }
        } else {
            cameraPosition = .region(region)
        }
    }

    private func focus(on recommendation: RankedFoodSpot) {
        guard let userLocation = locationProvider.location else { return }

        let spot = recommendation.spot.location
        let latitudeDifference = abs(spot.latitude - userLocation.latitude)
        let longitudeDifference = abs(spot.longitude - userLocation.longitude)
        let latitudeSpan = max(latitudeDifference * 2.8, 0.007)
        let longitudeSpan = max(longitudeDifference * 2.8, 0.007)

        // Shift the geographic center south so the selected place sits in the
        // open map band between the top controls and recommendation carousel.
        let center = CLLocationCoordinate2D(
            latitude: spot.latitude - latitudeSpan * 0.17,
            longitude: (spot.longitude + userLocation.longitude) / 2
        )

        withAnimation(.smooth(duration: 0.40)) {
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
    case tenMinuteWalk
    case oneKilometer
    case oneAndHalfKilometers
    case twoKilometers
    case fiveKilometers

    var id: Self { self }

    var meters: CLLocationDistance {
        switch self {
        case .veryClose: 250
        case .close: 500
        case .tenMinuteWalk: 800
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
        case .tenMinuteWalk: "10 min"
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
