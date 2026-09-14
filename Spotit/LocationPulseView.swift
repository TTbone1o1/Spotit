//
//  LocationPulseView.swift
//  Spotit
//

import SwiftUI

struct LocationPulseView: View {
    var diameter: CGFloat = 180

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startDate = Date()

    var body: some View {
        ZStack {
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) { context in
                    let elapsed = max(0, context.date.timeIntervalSince(startDate))
                    let phase = elapsed.truncatingRemainder(dividingBy: 2.8) / 2.8
                    let expansion = 1 - pow(1 - phase, 3)
                    // Fade in briefly at the start, then disappear before the
                    // cycle wraps. The restart is invisible, with no reversal.
                    let fadeIn = min(phase / 0.08, 1)
                    let opacity = 0.26 * fadeIn * pow(1 - phase, 2)

                    Circle()
                        .stroke(SpotitStyle.purple.opacity(opacity), lineWidth: 1.2)
                        .frame(
                            width: 44 + (diameter - 44) * expansion,
                            height: 44 + (diameter - 44) * expansion
                        )
                }
                .frame(width: diameter, height: diameter)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            SpotitStyle.purple.opacity(0.48),
                            SpotitStyle.purple.opacity(0.16),
                            SpotitStyle.purple.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 26
                    )
                )
                .frame(width: 52, height: 52)
                .blur(radius: 3)

            Circle()
                .fill(SpotitStyle.purple)
                .frame(width: 12, height: 12)
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { startDate = Date() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { startDate = Date() }
        }
    }
}

#Preview {
    LocationPulseView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 13 / 255, green: 11 / 255, blue: 11 / 255))
}
