//
//  SpotHomeComponents.swift
//  Spotit
//

import SwiftUI
import UIKit

enum SpotitStyle {
    static let purple = Color(red: 124 / 255, green: 75 / 255, blue: 226 / 255)
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.96, alpha: 1)
            : UIColor(red: 17 / 255, green: 17 / 255, blue: 17 / 255, alpha: 1)
    })
    static let secondaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.66, alpha: 1)
            : UIColor(red: 119 / 255, green: 119 / 255, blue: 119 / 255, alpha: 1)
    })
    static let warmBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 20 / 255, green: 19 / 255, blue: 18 / 255, alpha: 1)
            : UIColor(red: 250 / 255, green: 249 / 255, blue: 247 / 255, alpha: 1)
    })
    static let card = Color(uiColor: .secondarySystemBackground)
    static let mutedSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 47 / 255, green: 45 / 255, blue: 43 / 255, alpha: 1)
            : UIColor(red: 232 / 255, green: 230 / 255, blue: 226 / 255, alpha: 1)
    })
    static let divider = Color.primary.opacity(0.065)
}

struct MapRecommendationAnnotation: View {
    let symbolName: String
    let isSelected: Bool
    var isSaved = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(isSelected ? SpotitStyle.ink : SpotitStyle.card)
                .frame(width: isSelected ? 50 : 40, height: isSelected ? 50 : 40)
                .overlay {
                    Circle()
                        .stroke(
                            isSelected ? Color.white.opacity(0.92) : Color.primary.opacity(0.10),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
                .shadow(color: .black.opacity(isSelected ? 0.18 : 0.11), radius: 9, y: 4)

            Image(systemName: symbolName)
                .font(.system(size: isSelected ? 18 : 15, weight: .semibold))
                .foregroundStyle(isSelected ? SpotitStyle.warmBackground : SpotitStyle.ink)
                .frame(width: isSelected ? 50 : 40, height: isSelected ? 50 : 40)

            if isSaved {
                Circle()
                    .fill(SpotitStyle.purple)
                    .frame(width: 13, height: 13)
                    .overlay {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .overlay { Circle().stroke(.white, lineWidth: 1.5) }
            }
        }
        .frame(width: 56, height: 56)
        .contentShape(Circle())
        .scaleEffect(isSelected ? 1 : 0.98)
        .zIndex(isSelected ? 2 : 1)
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isSelected)
    }
}

struct MapControlButton: View {
    let systemImage: String
    let accessibilityLabel: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(SpotitStyle.ink)
            .frame(width: 46, height: 46)
            .background(SpotitStyle.card, in: Circle())
            .overlay { Circle().stroke(Color.primary.opacity(0.07), lineWidth: 1) }
            .shadow(color: .black.opacity(0.11), radius: 10, y: 4)
            .contentShape(Circle())
            .accessibilityLabel(accessibilityLabel)
    }
}

struct UserLocationMarker: View {
    let isDraggable: Bool
    let moveByTranslation: (CGSize) -> Void

    @GestureState private var isDragging = false
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Circle()
                .fill(SpotitStyle.purple.opacity(0.16))
                .frame(width: 38, height: 38)
            Circle()
                .fill(SpotitStyle.purple)
                .frame(width: 17, height: 17)
                .overlay { Circle().stroke(.white, lineWidth: 3) }
                .shadow(color: SpotitStyle.purple.opacity(0.35), radius: 4, y: 2)
        }
        .frame(width: 48, height: 48)
        .contentShape(Circle())
        .offset(dragOffset)
        .scaleEffect(isDragging ? 1.12 : 1)
        .zIndex(10)
        .animation(.smooth(duration: 0.18), value: isDragging)
        .highPriorityGesture(
            DragGesture(minimumDistance: isDraggable ? 1 : .greatestFiniteMagnitude)
                .updating($isDragging) { _, state, _ in state = true }
                .updating($dragOffset) { value, state, _ in state = value.translation }
                .onEnded { value in moveByTranslation(value.translation) }
        )
        .accessibilityLabel(isDraggable ? "Testing location" : "Your location")
        .accessibilityHint(isDraggable ? "Drag to explore recommendations from another location" : "Current location")
    }
}

struct RecommendationPanel<FilterContent: View>: View {
    let recommendations: [RankedFoodSpot]
    let selectedID: String?
    let worthTheWalkIDs: Set<String>
    let radiusDescription: String
    let isLoading: Bool
    let isSaved: (FoodSpot) -> Bool
    let select: (RankedFoodSpot) -> Void
    let open: (RankedFoodSpot) -> Void
    let toggleSaved: (FoodSpot) -> Void
    @ViewBuilder let filterContent: () -> FilterContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)

            if recommendations.isEmpty {
                if isLoading {
                    RecommendationLoadingRows()
                } else {
                    emptyState
                }
            } else {
                recommendationList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(SpotitStyle.warmBackground)
        .clipShape(.rect(topLeadingRadius: 30, topTrailingRadius: 30))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30)
                .stroke(Color.white.opacity(0.42), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.11), radius: 18, y: -4)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(recommendations.count) worth your time")
                    .font(.system(size: 23, weight: .bold, design: .default))
                    .foregroundStyle(SpotitStyle.ink)
                    .contentTransition(.numericText())

                Text(radiusDescription)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(SpotitStyle.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)
            filterContent()
        }
    }

    private var recommendationList: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(recommendations) { recommendation in
                        RecommendationRow(
                            recommendation: recommendation,
                            isSelected: recommendation.id == selectedID,
                            isWorthTheWalk: worthTheWalkIDs.contains(recommendation.id),
                            isSaved: isSaved(recommendation.spot),
                            select: { select(recommendation) },
                            open: { open(recommendation) },
                            toggleSaved: { toggleSaved(recommendation.spot) }
                        )
                        .id(recommendation.id)

                        if recommendation.id != recommendations.last?.id {
                            Rectangle()
                                .fill(SpotitStyle.divider)
                                .frame(height: 1)
                                .padding(.leading, 92)
                                .padding(.trailing, 20)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onChange(of: selectedID) { _, id in
                guard let id else { return }
                withAnimation(.smooth(duration: 0.32)) {
                    reader.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Nothing worth the detour yet.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SpotitStyle.ink)
            Text("Try exploring a little farther with Filter.")
                .font(.subheadline)
                .foregroundStyle(SpotitStyle.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 22)
    }
}

struct RecommendationRow: View {
    let recommendation: RankedFoodSpot
    let isSelected: Bool
    let isWorthTheWalk: Bool
    let isSaved: Bool
    let select: () -> Void
    let open: () -> Void
    let toggleSaved: () -> Void

    private var spot: FoodSpot { recommendation.spot }

    var body: some View {
        Button {
            select()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(260))
                open()
            }
        } label: {
            HStack(spacing: 13) {
                RecommendationThumbnail(spot: spot)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(spot.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(SpotitStyle.ink)
                            .lineLimit(1)

                        if isSaved {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(SpotitStyle.purple)
                        }
                    }

                    ratingLine

                    HStack(spacing: 6) {
                        CategoryPill(text: spot.neighborhood ?? spot.category.title)
                        if isWorthTheWalk {
                            WorthTheWalkBadge(compact: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                WalkTimeView(minutes: recommendation.walkingMinutes)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SpotitStyle.purple.opacity(0.075))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: toggleSaved) {
                Label(isSaved ? "Remove from Saved" : "Save Place", systemImage: isSaved ? "heart.slash" : "heart")
            }
            Button(action: open) {
                Label("View Details", systemImage: "arrow.up.right")
            }
        }
        .accessibilityHint("Selects this place on the map and opens its details")
    }

    private var ratingLine: some View {
        HStack(spacing: 4) {
            if let rating = spot.rating {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .bold))
                Text(rating.formatted(.number.precision(.fractionLength(1))))
                    .foregroundStyle(SpotitStyle.ink)
                if let reviewCount = spot.reviewCount {
                    Text("(\(reviewCount.formatted(.number.notation(.compactName))))")
                }
                Text("·")
            }
            Text(spot.category.title)
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(SpotitStyle.secondaryText)
        .lineLimit(1)
    }
}

struct RecommendationThumbnail: View {
    let spot: FoodSpot

    var body: some View {
        FoodSpotImageView(spot: spot, snapshotSize: CGSize(width: 240, height: 240))
            .frame(width: 62, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }
}

struct WalkTimeView: View {
    let minutes: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: -1) {
            Text(minutes.formatted())
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(SpotitStyle.ink)
                .monospacedDigit()
            Text("MIN")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(SpotitStyle.secondaryText)
        }
        .frame(width: 38, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(minutes) minute walk")
    }
}

struct CategoryPill: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.65)
            .foregroundStyle(SpotitStyle.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(SpotitStyle.mutedSurface.opacity(0.78), in: Capsule())
    }
}

struct WorthTheWalkBadge: View {
    var compact = false

    var body: some View {
        Label("WORTH THE WALK", systemImage: "figure.walk")
            .font(.system(size: compact ? 8 : 10, weight: .bold))
            .tracking(compact ? 0.25 : 0.7)
            .foregroundStyle(SpotitStyle.purple)
            .padding(.horizontal, compact ? 6 : 9)
            .padding(.vertical, compact ? 3 : 6)
            .background(SpotitStyle.purple.opacity(0.10), in: Capsule())
            .fixedSize()
    }
}

struct SpotitPlacePlaceholder: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SpotitStyle.mutedSurface))
            let spacing: CGFloat = 13
            var path = Path()
            for offset in stride(from: -size.height, through: size.width + size.height, by: spacing) {
                path.move(to: CGPoint(x: offset, y: size.height))
                path.addLine(to: CGPoint(x: offset + size.height, y: 0))
            }
            context.stroke(path, with: .color(Color.primary.opacity(0.045)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

private struct RecommendationLoadingRows: View {
    var body: some View {
        VStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 13) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SpotitStyle.mutedSurface)
                        .frame(width: 62, height: 62)
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(SpotitStyle.mutedSurface).frame(width: 142, height: 12)
                        Capsule().fill(SpotitStyle.mutedSurface.opacity(0.75)).frame(width: 104, height: 9)
                        Capsule().fill(SpotitStyle.mutedSurface.opacity(0.75)).frame(width: 72, height: 13)
                    }
                    Spacer()
                    Capsule().fill(SpotitStyle.mutedSurface).frame(width: 28, height: 26)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
        .opacity(0.72)
        .accessibilityLabel("Finding nearby places")
    }
}
