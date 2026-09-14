//
//  CollapsibleRecommendationCarousel.swift
//  Spotit
//

import SwiftUI
import UIKit

enum CarouselPresentationState {
    case expanded
    case collapsed

    static let settleAnimation = Animation.spring(response: 0.45, dampingFraction: 0.82)
}

struct CollapsibleRecommendationCarousel<Content: View>: View {
    @Binding var presentation: CarouselPresentationState
    let cardHeight: CGFloat
    @ViewBuilder let content: () -> Content

    @State private var dragOffset: CGFloat = 0

    private var isCollapsed: Bool { presentation == .collapsed }
    private var travel: CGFloat { cardHeight + 36 }
    private var offset: CGFloat {
        min(max((isCollapsed ? travel : 0) + dragOffset, 0), travel)
    }
    private var progress: CGFloat { offset / travel }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Keep the horizontal ScrollView mounted so its position and selected
            // card survive collapse. Hidden cards cannot receive map touches.
            content()
                .frame(height: cardHeight)
                .gesture(verticalDrag(restoring: false))
                .offset(y: offset)
                .opacity(1 - min(max((progress - 0.70) / 0.30, 0), 1))
                .allowsHitTesting(!isCollapsed)
                .accessibilityAction(named: "Collapse recommendations") {
                    settle(to: .collapsed)
                }
                .accessibilityHidden(isCollapsed)

            if isCollapsed {
                restoreHandle
                    .transition(.opacity)
            }
        }
        .frame(height: cardHeight)
        .animation(CarouselPresentationState.settleAnimation, value: presentation)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: presentation)
    }

    private var restoreHandle: some View {
        Button { settle(to: .expanded) } label: {
            Capsule()
                .fill(.regularMaterial)
                .overlay {
                    Capsule().fill(SpotitStyle.ink.opacity(0.30))
                }
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.30), lineWidth: 0.5)
                }
                .frame(width: 50, height: 6)
                .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
                // A quiet six-point line with an accessible touch target.
                .frame(width: 76, height: 44, alignment: .bottom)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .gesture(verticalDrag(restoring: true))
        .opacity(min(progress / 0.35, 1))
        .accessibilityLabel("Show recommendations")
        .accessibilityHint("Tap or swipe up to restore the cards")
        .accessibilityIdentifier("spotit.carousel.restore")
    }

    private func verticalDrag(restoring: Bool) -> CarouselVerticalDrag {
        CarouselVerticalDrag(
            restoring: restoring,
            changed: { translation in
                dragOffset = restoring ? min(translation, 0) : max(translation, 0)
            },
            ended: { translation, velocity in
                let distance = restoring ? -translation : translation
                let speed = restoring ? -velocity : velocity
                let projectedDistance = distance + speed * 0.18
                let threshold: CGFloat = restoring ? 70 : 100
                let shouldComplete = distance >= threshold
                    || (distance > 16 && speed > 350 && projectedDistance >= threshold)
                settle(to: shouldComplete ? (restoring ? .expanded : .collapsed) : presentation)
            },
            cancelled: { settle(to: presentation) }
        )
    }

    private func settle(to state: CarouselPresentationState) {
        withAnimation(CarouselPresentationState.settleAnimation) {
            presentation = state
            dragOffset = 0
        }
    }
}

// Decide direction before recognition, rather than swallowing a horizontal
// ScrollView drag and deciding afterward. UIKit locks that decision until lift.
private struct CarouselVerticalDrag: UIGestureRecognizerRepresentable {
    let restoring: Bool
    let changed: (CGFloat) -> Void
    let ended: (CGFloat, CGFloat) -> Void
    let cancelled: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(restoring: restoring)
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.restoring = restoring
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        // Window coordinates stay stable as the card moves with the finger.
        let translation = recognizer.translation(in: recognizer.view?.window).y
        let velocity = recognizer.velocity(in: recognizer.view?.window).y
        switch recognizer.state {
        case .began, .changed:
            changed(translation)
        case .ended:
            ended(translation, velocity)
        case .cancelled, .failed:
            cancelled()
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var restoring: Bool

        init(restoring: Bool) {
            self.restoring = restoring
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let translation = pan.translation(in: pan.view?.window)
            let isVertical = abs(translation.y) > abs(translation.x) * 1.4
            return isVertical && (restoring ? translation.y < 0 : translation.y > 0)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // A horizontal UIScrollView also begins pans for vertical movement.
            // Let our direction-filtered pan coexist with its native recognizer.
            otherGestureRecognizer is UIPanGestureRecognizer
        }
    }
}
