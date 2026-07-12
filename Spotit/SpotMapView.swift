//
//  SpotMapView.swift
//  Spotit
//
//  Created by Abraham May on 7/9/26.
//

import MapKit
import SwiftUI

struct SpotMapView: View {
    @State private var cameraPosition: MapCameraPosition = .region(Self.destinationsRegion)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $cameraPosition, bounds: Self.destinationCameraBounds) {
                ForEach(Self.destinations) { destination in
                    Marker(
                        destination.name,
                        systemImage: "building.2.fill",
                        coordinate: destination.coordinate
                    )
                    .tint(.red)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 6) {
                Text("Spotit")
                    .font(.title2.weight(.bold))
                Text("Tokyo  •  Kyoto  •  Osaka")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding()
        }
    }

    private static let destinations = [
        Destination(name: "Tokyo", latitude: 35.6762, longitude: 139.6503),
        Destination(name: "Kyoto", latitude: 35.0116, longitude: 135.7681),
        Destination(name: "Osaka", latitude: 34.6937, longitude: 135.5023)
    ]

    private static let destinationsRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5, longitude: 138.8),
        span: MKCoordinateSpan(latitudeDelta: 17.5, longitudeDelta: 18.5)
    )

    private static let destinationBoundsRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.6, longitude: 138.4),
        span: MKCoordinateSpan(latitudeDelta: 24.0, longitudeDelta: 26.0)
    )

    private static let destinationCameraBounds = MapCameraBounds(
        centerCoordinateBounds: destinationBoundsRegion,
        minimumDistance: 25_000,
        maximumDistance: 4_400_000
    )
}

private struct Destination: Identifiable {
    let name: String
    let coordinate: CLLocationCoordinate2D

    var id: String { name }

    init(name: String, latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        self.name = name
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

#Preview {
    SpotMapView()
}
