//
//  ContentView.swift
//  Spotit
//
//  Created by Abraham May on 7/9/26.
//

import CoreLocation
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var locationProvider = LocationProvider(simulatesHarajuku: true)

    // Session-only for now: every fresh launch starts with the opening moment.
    // A future first-launch policy belongs here, without changing either screen.
    @State private var hasEnteredDiscover = false
    @State private var hasRequestedEntry = false

    var body: some View {
        ZStack {
            if hasEnteredDiscover {
                SpotMapView(locationProvider: locationProvider)
                    .transition(.opacity)
            } else {
                SpotitEntryView(
                    isRequestingLocation: locationProvider.isRequestingAuthorization,
                    locationExplanation: locationExplanation,
                    onContinue: requestEntry
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .preferredColorScheme(hasEnteredDiscover ? nil : .dark)
        .onChange(of: locationProvider.authorizationStatus) { _, _ in
            enterDiscoverIfAuthorized()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // Also handles permission changes made in Settings after a denial.
            locationProvider.refreshAuthorizationStatus()
            enterDiscoverIfAuthorized()
        }
    }

    private var locationExplanation: String? {
        guard hasRequestedEntry else { return nil }

        switch locationProvider.authorizationStatus {
        case .denied:
            return "Location access is off. Allow it for Spotit in Settings to find places nearby."
        case .restricted:
            return "Location access is restricted on this device. You can continue once access is available."
        default:
            return nil
        }
    }

    private func requestEntry() {
        hasRequestedEntry = true
        locationProvider.requestAuthorization()
        enterDiscoverIfAuthorized()
    }

    private func enterDiscoverIfAuthorized() {
        guard hasRequestedEntry, !hasEnteredDiscover else { return }
        switch locationProvider.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationProvider.start()
            withAnimation(.easeInOut(duration: 0.4)) {
                hasEnteredDiscover = true
            }
        default:
            break
        }
    }
}

#Preview {
    ContentView()
}
