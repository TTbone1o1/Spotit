//
//  FoodSpotDetailView.swift
//  Spotit
//

import MapKit
import SwiftUI
import UIKit

struct FoodSpotImageView: View {
    let spot: FoodSpot
    var cornerRadius: CGFloat = 0
    var snapshotSize = CGSize(width: 800, height: 500)

    var body: some View {
        Group {
            if let imageURL = spot.imageURLs.first {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        loadingPlaceholder
                    case .failure:
                        LookAroundPlaceImage(spot: spot, snapshotSize: snapshotSize)
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                LookAroundPlaceImage(spot: spot, snapshotSize: snapshotSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var loadingPlaceholder: some View {
        ZStack {
            placeholder
            ProgressView()
                .tint(.white)
        }
    }

    private var placeholder: some View {
        SpotitPlacePlaceholder()
    }
}

private struct LookAroundPlaceImage: View {
    let spot: FoodSpot
    let snapshotSize: CGSize

    @State private var image: UIImage?
    @State private var hasFinishedLoading = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if hasFinishedLoading {
                placeholder
            } else {
                ZStack {
                    placeholder
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .task(id: cacheKey) {
            await loadImage()
        }
    }

    private var cacheKey: NSString {
        "\(spot.id)-\(Int(snapshotSize.width))x\(Int(snapshotSize.height))" as NSString
    }

    @MainActor
    private func loadImage() async {
        if let cachedImage = LookAroundImageCache.images.object(forKey: cacheKey) {
            image = cachedImage
            hasFinishedLoading = true
            return
        }

        defer { hasFinishedLoading = true }

        do {
            let request = MKLookAroundSceneRequest(coordinate: spot.location.coordinate)
            guard let scene = try await request.scene else { return }

            let options = MKLookAroundSnapshotter.Options()
            options.size = snapshotSize

            let snapshotter = MKLookAroundSnapshotter(scene: scene, options: options)
            let snapshot = try await snapshotter.snapshot
            guard !Task.isCancelled else { return }

            LookAroundImageCache.images.setObject(snapshot.image, forKey: cacheKey)
            image = snapshot.image
        } catch {
            // Some locations do not have Look Around coverage; use the category fallback there.
        }
    }

    private var placeholder: some View {
        SpotitPlacePlaceholder()
    }
}

@MainActor
private enum LookAroundImageCache {
    static let images = NSCache<NSString, UIImage>()
}

struct FoodSpotDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let spot: FoodSpot
    let userLocation: GeoPoint?
    let isWorthTheWalk: Bool
    let toggleSaved: () -> Void
    @State private var isSaved: Bool

    init(
        spot: FoodSpot,
        userLocation: GeoPoint?,
        isWorthTheWalk: Bool = false,
        isSaved: Bool = false,
        toggleSaved: @escaping () -> Void = {}
    ) {
        self.spot = spot
        self.userLocation = userLocation
        self.isWorthTheWalk = isWorthTheWalk
        self.toggleSaved = toggleSaved
        _isSaved = State(initialValue: isSaved)
    }

    private var distance: CLLocationDistance? {
        userLocation.map(spot.distance)
    }

    private var walkingMinutes: Int? {
        distance.map { max(1, Int(ceil($0 / 80))) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleBlock
                        .padding(.horizontal, 20)

                    imageGallery
                        .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 24) {
                        summaryBlock
                        locationMap
                        detailsBlock
                        directionsButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .padding(.top, 12)
            }
            .background(SpotitStyle.warmBackground)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(SpotitStyle.ink)
                            .frame(width: 36, height: 36)
                            .background(SpotitStyle.card, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSaved.toggle()
                        toggleSaved()
                    } label: {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isSaved ? SpotitStyle.purple : SpotitStyle.ink)
                            .frame(width: 36, height: 36)
                            .background(SpotitStyle.card, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityLabel(isSaved ? "Remove from saved" : "Save place")
                }
            }
            .toolbarBackground(SpotitStyle.warmBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var imageGallery: some View {
        if spot.imageURLs.count > 1 {
            TabView {
                ForEach(spot.imageURLs, id: \.self) { imageURL in
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            FoodSpotImageView(spot: spot)
                        }
                    }
                    .clipped()
                }
            }
            .tabViewStyle(.page)
            .frame(height: 286)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            FoodSpotImageView(spot: spot, cornerRadius: 24)
                .frame(height: 286)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text((spot.neighborhood ?? spot.category.title).uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.25)
                .foregroundStyle(SpotitStyle.secondaryText)

            Text(spot.name)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(SpotitStyle.ink)

            if isWorthTheWalk {
                WorthTheWalkBadge()
            }

            HStack(spacing: 8) {
                if let rating = spot.rating {
                    Label(
                        rating.formatted(.number.precision(.fractionLength(1))),
                        systemImage: "star.fill"
                    )
                    .foregroundStyle(SpotitStyle.ink)
                }

                if let reviewCount = spot.reviewCount {
                    Text("(\(reviewCount.formatted(.number.notation(.compactName))))")
                }

                if spot.rating != nil { Text("·") }
                Text(spot.category.title)
            }
            .font(.subheadline)
            .foregroundStyle(SpotitStyle.secondaryText)

            HStack(spacing: 10) {
                if let distance, let walkingMinutes {
                    Label("\(walkingMinutes) min walk", systemImage: "figure.walk")
                    Text("·")
                    Text(Self.distanceText(distance))
                }
                if let priceLevel = spot.priceLevel {
                    Text("·")
                    Text(Self.priceText(priceLevel))
                }
                if let isOpen = spot.isOpen {
                    Text("·")
                    Text(isOpen ? "Open" : "Closed")
                        .foregroundStyle(isOpen ? .green : .red)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(SpotitStyle.purple)
        }
    }

    private var summaryBlock: some View {
        Text(spot.summary ?? "A nearby \(spot.category.title.lowercased()) option in \(spot.neighborhood ?? "Japan").")
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(SpotitStyle.secondaryText)
            .lineSpacing(4)
    }

    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Details")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(SpotitStyle.ink)

            if let address = spot.address, !address.isEmpty {
                DetailRow(icon: "mappin.and.ellipse", title: "Address", value: address)
            }

            if !spot.openingHours.isEmpty {
                DetailRow(
                    icon: "clock",
                    title: "Opening hours",
                    value: spot.openingHours.joined(separator: "\n")
                )
            }

            if let phoneNumber = spot.phoneNumber, !phoneNumber.isEmpty {
                DetailRow(icon: "phone", title: "Phone", value: phoneNumber)
            }

            if spot.address == nil && spot.openingHours.isEmpty && spot.phoneNumber == nil {
                Text("Additional restaurant details are not available from this listing yet.")
                    .font(.subheadline)
                    .foregroundStyle(SpotitStyle.secondaryText)
            }
        }
    }

    private var locationMap: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: spot.location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        ))) {
            Annotation(spot.name, coordinate: spot.location.coordinate) {
                MapRecommendationAnnotation(
                    symbolName: spot.category.symbolName,
                    isSelected: true,
                    isSaved: isSaved
                )
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Map showing \(spot.name)")
    }

    private var directionsButton: some View {
        Button(action: openDirections) {
            Label("Walk there", systemImage: "figure.walk")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(SpotitStyle.warmBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(SpotitStyle.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func openDirections() {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: "\(spot.location.latitude),\(spot.location.longitude)"),
            URLQueryItem(name: "q", value: spot.name),
            URLQueryItem(name: "dirflg", value: "w")
        ]
        guard let url = components?.url else { return }
        openURL(url)
    }

    private static func distanceText(_ distance: CLLocationDistance) -> String {
        if distance < 1_000 {
            return "\(Int((distance / 10).rounded() * 10)) m"
        }
        return String(format: "%.1f km", distance / 1_000)
    }

    private static func priceText(_ level: Int) -> String {
        String(repeating: "¥", count: min(max(level, 1), 4))
    }
}

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(SpotitStyle.purple)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SpotitStyle.secondaryText)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(SpotitStyle.ink)
            }
        }
    }
}
