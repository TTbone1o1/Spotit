//
//  SpotitEntryView.swift
//  Spotit
//

import SwiftUI

struct SpotitEntryView: View {
    let isRequestingLocation: Bool
    let locationExplanation: String?
    let onContinue: () -> Void

    @ScaledMetric(relativeTo: .title) private var headlineSize = 28
    @ScaledMetric(relativeTo: .footnote) private var descriptionSize = 13
    @ScaledMetric(relativeTo: .callout) private var buttonSize = 16
    @AccessibilityFocusState private var explanationIsFocused: Bool

    private let background = Color(red: 13 / 255, green: 11 / 255, blue: 11 / 255)
    private let headlineColor = Color(red: 245 / 255, green: 242 / 255, blue: 239 / 255)
    private let descriptionColor = Color(red: 119 / 255, green: 114 / 255, blue: 111 / 255)

    var body: some View {
        GeometryReader { geometry in
            let isCompactHeight = geometry.size.height < 500

            VStack(spacing: 0) {
                // On compact heights or larger type, the copy can scroll while
                // the single CTA stays within reach above the bottom safe area.
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: isCompactHeight ? 24 : geometry.size.height * 0.28)
                            .accessibilityHidden(true)

                        LocationPulseView(diameter: min(180, geometry.size.width * 0.46))
                            .frame(height: 12)
                            .padding(.bottom, isCompactHeight ? 32 : 60)

                        Text("Start where you're\nstanding")
                            .font(.system(size: headlineSize, weight: .regular, design: .serif))
                            .foregroundStyle(headlineColor)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)

                        Text("Spotit uses your location to find the\nfew places genuinely worth walking to.\nNothing is stored, nothing is shared.")
                            .font(.system(size: descriptionSize, weight: .regular))
                            .foregroundStyle(descriptionColor)
                            .lineSpacing(4.5)
                            .frame(maxWidth: 290)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 16)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                VStack(spacing: 16) {
                    if let locationExplanation {
                        Text(locationExplanation)
                            .font(.system(size: descriptionSize))
                            .foregroundStyle(headlineColor.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityFocused($explanationIsFocused)
                    }

                    Button(action: onContinue) {
                        Text("Spot it, save it, walk it")
                            .font(.system(size: buttonSize, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(SpotitStyle.purple, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(isRequestingLocation)
                    .accessibilityIdentifier("spotit.entry.continue")
                    .accessibilityValue(isRequestingLocation ? "Waiting for location permission" : "")
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .background(background.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .onChange(of: locationExplanation) { _, explanation in
            explanationIsFocused = explanation != nil
        }
    }
}

#Preview {
    SpotitEntryView(isRequestingLocation: false, locationExplanation: nil, onContinue: {})
        .preferredColorScheme(.dark)
}
