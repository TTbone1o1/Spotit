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
    static let card = Color(uiColor: .systemBackground)
    static let mutedSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 47 / 255, green: 45 / 255, blue: 43 / 255, alpha: 1)
            : UIColor(red: 232 / 255, green: 230 / 255, blue: 226 / 255, alpha: 1)
    })
}

enum SpotitHomeTab: String, CaseIterable, Identifiable {
    case discover = "Discover"
    case saved = "Saved"

    var id: Self { self }
    var symbolName: String { self == .discover ? "safari.fill" : "heart.fill" }
}

struct MapRecommendationAnnotation: View {
    let symbolName: String
    let isSelected: Bool
    var isSaved = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(isSelected ? SpotitStyle.ink : SpotitStyle.card)
                .frame(width: isSelected ? 54 : 42, height: isSelected ? 54 : 42)
                .overlay {
                    Circle().stroke(
                        isSelected ? Color.white.opacity(0.96) : Color.primary.opacity(0.09),
                        lineWidth: isSelected ? 2.5 : 1
                    )
                }
                .shadow(color: .black.opacity(isSelected ? 0.18 : 0.11), radius: 10, y: 4)

            Image(systemName: symbolName)
                .font(.system(size: isSelected ? 19 : 15, weight: .semibold))
                .foregroundStyle(isSelected ? SpotitStyle.warmBackground : SpotitStyle.ink)
                .frame(width: isSelected ? 54 : 42, height: isSelected ? 54 : 42)

            if isSaved {
                Circle()
                    .fill(SpotitStyle.purple)
                    .frame(width: 14, height: 14)
                    .overlay {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .overlay { Circle().stroke(.white, lineWidth: 1.5) }
            }
        }
        .frame(width: 60, height: 60)
        .contentShape(Circle())
        .scaleEffect(isSelected ? 1 : 0.92)
        .zIndex(isSelected ? 20 : 1)
        .animation(.spring(response: 0.32, dampingFraction: 0.74), value: isSelected)
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
            .background(SpotitStyle.card.opacity(0.97), in: Circle())
            .overlay { Circle().stroke(Color.primary.opacity(0.06), lineWidth: 1) }
            .shadow(color: .black.opacity(0.09), radius: 9, y: 3)
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
                .fill(SpotitStyle.purple.opacity(0.13))
                .frame(width: 42, height: 42)
            Circle()
                .fill(.white)
                .frame(width: 28, height: 28)
            Circle()
                .fill(SpotitStyle.purple)
                .frame(width: 19, height: 19)
        }
        .shadow(color: SpotitStyle.purple.opacity(0.22), radius: 5, y: 2)
        .frame(width: 50, height: 50)
        .contentShape(Circle())
        .offset(dragOffset)
        .scaleEffect(isDragging ? 1.12 : 1)
        .zIndex(30)
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

struct DiscoverSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(SpotitStyle.secondaryText)

            TextField("Ramen, coffee, anything…", text: $text)
                .font(.system(size: 16))
                .foregroundStyle(SpotitStyle.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(SpotitStyle.secondaryText.opacity(0.75))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 17)
        .frame(height: 54)
        .background(SpotitStyle.card.opacity(0.97), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(Color.primary.opacity(0.045), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.075), radius: 11, y: 4)
    }
}

struct WalkingRadiusLabel: View {
    let minutes: Int

    var body: some View {
        Text("\(minutes)m")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(SpotitStyle.warmBackground)
            .frame(width: 52, height: 52)
            .background(SpotitStyle.ink, in: Circle())
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .accessibilityLabel("\(minutes) minute walking radius")
    }
}

struct WorthYourTimeIndicator: View {
    let count: Int
    let outsideCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(SpotitStyle.purple)
                .frame(width: 7, height: 7)
            Text("\(count) worth your time")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.white)

            if outsideCount > 0 {
                Text("·")
                    .foregroundStyle(.white.opacity(0.42))
                Text("+\(outsideCount)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SpotitStyle.purple)
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 38)
        .background(Color.black.opacity(0.91), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .shadow(color: .black.opacity(0.09), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
    }
}

struct RecommendationCarousel: View {
    let recommendations: [RankedFoodSpot]
    @Binding var selectedID: String?
    let worthTheWalkIDs: Set<String>
    let isLoading: Bool
    let emptyTitle: String
    let isSaved: (FoodSpot) -> Bool
    let open: (RankedFoodSpot) -> Void
    let toggleSaved: (FoodSpot) -> Void

    private var closestID: String? {
        recommendations.min(by: { $0.distance < $1.distance })?.id
    }

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width * 0.82
            let cardHeight = min(max(geometry.size.height, 315), 350)

            Group {
                if recommendations.isEmpty {
                    if isLoading {
                        RecommendationCardSkeleton(width: cardWidth, height: cardHeight)
                            .padding(.leading, 20)
                    } else {
                        emptyState(width: cardWidth, height: cardHeight)
                            .padding(.leading, 20)
                    }
                } else {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 14) {
                            ForEach(recommendations) { recommendation in
                                DiscoveryRecommendationCard(
                                    recommendation: recommendation,
                                    isClosest: recommendation.id == closestID,
                                    isWorthTheWalk: worthTheWalkIDs.contains(recommendation.id),
                                    isSaved: isSaved(recommendation.spot),
                                    open: { open(recommendation) },
                                    toggleSaved: { toggleSaved(recommendation.spot) }
                                )
                                .frame(width: cardWidth, height: cardHeight)
                                .id(recommendation.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, 20, for: .scrollContent)
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .scrollPosition(id: $selectedID, anchor: .leading)
                }
            }
        }
    }

    private func emptyState(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "map")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(SpotitStyle.purple)
            Text(emptyTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(SpotitStyle.ink)
            Text("Try another search or explore a little farther.")
                .font(.subheadline)
                .foregroundStyle(SpotitStyle.secondaryText)
        }
        .frame(width: width, height: height, alignment: .leading)
        .padding(.horizontal, 20)
        .background(SpotitStyle.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 14, y: 5)
    }
}

struct DiscoveryRecommendationCard: View {
    let recommendation: RankedFoodSpot
    let isClosest: Bool
    let isWorthTheWalk: Bool
    let isSaved: Bool
    let open: () -> Void
    let toggleSaved: () -> Void

    private var spot: FoodSpot { recommendation.spot }

    var body: some View {
        GeometryReader { geometry in
            let imageHeight = min(max(geometry.size.height * 0.46, 145), 160)

            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    FoodSpotImageView(spot: spot, snapshotSize: CGSize(width: 700, height: 360))
                        .frame(height: imageHeight)
                        .clipped()

                    Button(action: toggleSaved) {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isSaved ? SpotitStyle.purple : SpotitStyle.ink)
                            .frame(width: 36, height: 36)
                            .background(SpotitStyle.card.opacity(0.94), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityLabel(isSaved ? "Remove from saved" : "Save place")
                }
                .overlay(alignment: .bottomLeading) {
                    if isClosest {
                        Text("CLOSEST")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.85)
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 13)
                            .frame(height: 32)
                            .background(SpotitStyle.card.opacity(0.96), in: Capsule())
                            .padding(.leading, 16)
                            .padding(.bottom, 15)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(spot.name)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(SpotitStyle.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if isWorthTheWalk {
                            WorthTheWalkBadge(compact: true)
                        }
                    }

                    metadata

                    Text(spot.summary ?? "A nearby \(spot.category.title.lowercased()) spot worth knowing about in \(spot.neighborhood ?? "the neighborhood").")
                        .font(.system(size: 14.5))
                        .foregroundStyle(Color.primary.opacity(0.70))
                        .lineSpacing(3)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    Label("\(recommendation.walkingMinutes) min", systemImage: "figure.walk")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SpotitStyle.purple)
                        .padding(.horizontal, 13)
                        .frame(height: 31)
                        .background(SpotitStyle.purple.opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, 19)
                .padding(.top, 16)
                .padding(.bottom, 17)
            }
            .background(SpotitStyle.card)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.primary.opacity(0.035), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 14, y: 5)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .onTapGesture(perform: open)
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint("Opens place details")
    }

    private var metadata: some View {
        HStack(spacing: 4) {
            if let rating = spot.rating {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(SpotitStyle.ink)
                Text(rating.formatted(.number.precision(.fractionLength(1))))
                    .fontWeight(.semibold)
                    .foregroundStyle(SpotitStyle.ink)
                if let reviewCount = spot.reviewCount {
                    Text("(\(reviewCount.formatted(.number.notation(.compactName))))")
                }
                Text("·")
            }
            if let priceLevel = spot.priceLevel {
                Text(String(repeating: "¥", count: min(max(priceLevel, 1), 4)))
                Text("·")
            }
            Text(spot.neighborhood ?? spot.category.title)
        }
        .font(.system(size: 13))
        .foregroundStyle(SpotitStyle.secondaryText)
        .lineLimit(1)
    }
}

struct SpotitBottomTabBar: View {
    @Binding var selection: SpotitHomeTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SpotitHomeTab.allCases) { tab in
                Button {
                    withAnimation(.smooth(duration: 0.25)) { selection = tab }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 23, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(selection == tab ? SpotitStyle.purple : Color.secondary.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.primary.opacity(0.055)).frame(height: 0.5)
        }
    }
}

struct WorthTheWalkBadge: View {
    var compact = false

    var body: some View {
        Label("WORTH THE WALK", systemImage: "figure.walk")
            .font(.system(size: compact ? 8 : 10, weight: .bold))
            .tracking(compact ? 0.2 : 0.7)
            .foregroundStyle(SpotitStyle.purple)
            .padding(.horizontal, compact ? 6 : 9)
            .padding(.vertical, compact ? 4 : 6)
            .background(SpotitStyle.purple.opacity(0.10), in: Capsule())
            .fixedSize()
    }
}

struct SpotitPlacePlaceholder: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SpotitStyle.mutedSurface))
            let spacing: CGFloat = 16
            var path = Path()
            for offset in stride(from: -size.height, through: size.width + size.height, by: spacing) {
                path.move(to: CGPoint(x: offset, y: size.height))
                path.addLine(to: CGPoint(x: offset + size.height, y: 0))
            }
            context.stroke(path, with: .color(Color.primary.opacity(0.028)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

private struct RecommendationCardSkeleton: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(SpotitStyle.mutedSurface)
                .frame(height: min(max(height * 0.46, 145), 160))
            VStack(alignment: .leading, spacing: 12) {
                Capsule().fill(SpotitStyle.mutedSurface).frame(width: width * 0.56, height: 18)
                Capsule().fill(SpotitStyle.mutedSurface.opacity(0.75)).frame(width: width * 0.42, height: 11)
                Capsule().fill(SpotitStyle.mutedSurface.opacity(0.65)).frame(height: 11)
                Capsule().fill(SpotitStyle.mutedSurface.opacity(0.65)).frame(width: width * 0.72, height: 11)
                Spacer()
                Capsule().fill(SpotitStyle.purple.opacity(0.10)).frame(width: 78, height: 31)
            }
            .padding(19)
        }
        .frame(width: width, height: height)
        .background(SpotitStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.09), radius: 14, y: 5)
        .opacity(0.78)
        .accessibilityLabel("Finding nearby places")
    }
}
