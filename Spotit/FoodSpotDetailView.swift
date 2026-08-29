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
        ZStack {
            LinearGradient(
                colors: [.orange.opacity(0.92), .pink.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: spot.category.symbolName)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
        }
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
        ZStack {
            LinearGradient(
                colors: [.orange.opacity(0.92), .pink.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: spot.category.symbolName)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
        }
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

    private var distance: CLLocationDistance? {
        userLocation.map(spot.distance)
    }

    private var walkingMinutes: Int? {
        distance.map { max(1, Int(ceil($0 / 80))) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    imageGallery

                    VStack(alignment: .leading, spacing: 16) {
                        titleBlock
                        summaryBlock
                        detailsBlock
                        locationMap
                        directionsButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.bordered)
                }
            }
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
            .frame(height: 300)
        } else {
            FoodSpotImageView(spot: spot)
                .frame(height: 300)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(spot.name)
                .font(.largeTitle.bold())

            HStack(spacing: 8) {
                Text(spot.category.title)

                if let rating = spot.rating {
                    Text("·")
                    Label(
                        rating.formatted(.number.precision(.fractionLength(1))),
                        systemImage: "star.fill"
                    )
                    .foregroundStyle(.orange)
                }

                if let reviewCount = spot.reviewCount {
                    Text("(\(reviewCount.formatted()) reviews)")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                if let distance, let walkingMinutes {
                    Text("\(Self.distanceText(distance)) · ~\(walkingMinutes) min walk")
                }
                if let priceLevel = spot.priceLevel {
                    Text(Self.priceText(priceLevel))
                }
                if let isOpen = spot.isOpen {
                    Text(isOpen ? "Open" : "Closed")
                        .foregroundStyle(isOpen ? .green : .red)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    private var summaryBlock: some View {
        Text(spot.summary ?? "A nearby \(spot.category.title.lowercased()) option in \(spot.neighborhood ?? "Japan").")
            .font(.body)
            .foregroundStyle(.secondary)
    }

    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Details")
                .font(.title3.bold())

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
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var locationMap: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: spot.location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        ))) {
            Marker(spot.name, coordinate: spot.location.coordinate)
                .tint(.purple)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityLabel("Map showing \(spot.name)")
    }

    private var directionsButton: some View {
        Button(action: openDirections) {
            Label("Walking Directions", systemImage: "figure.walk")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .controlSize(.large)
        .tint(.purple)
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
                .foregroundStyle(.purple)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
            }
        }
    }
}
