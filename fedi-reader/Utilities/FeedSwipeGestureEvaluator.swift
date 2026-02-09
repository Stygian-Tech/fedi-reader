//
//  FeedSwipeGestureEvaluator.swift
//  fedi-reader
//
//  Shared swipe heuristics for feed-to-feed navigation.
//

import CoreGraphics

enum FeedSwipeDirection: Equatable {
    case previous
    case next
    case none
}

struct FeedSwipeGestureEvaluator {
    static let horizontalIntentDistance: CGFloat = 10
    static let swipeCommitDistance: CGFloat = 56
    static let predictedCommitDistance: CGFloat = 84
    static let visualFollowFactor: CGFloat = 0.35
    static let maxVisualOffset: CGFloat = 72
    static let postSwipeSuppressionNanoseconds: UInt64 = 120_000_000
    private static let horizontalDominanceRatio: CGFloat = 1.05

    static func visualOffset(translation: CGSize) -> CGFloat {
        guard isHorizontalIntent(translation: translation) else {
            return 0
        }

        let resisted = translation.width * visualFollowFactor
        return max(-maxVisualOffset, min(maxVisualOffset, resisted))
    }

    static func shouldCommit(
        translation: CGSize,
        predictedEndTranslation: CGSize
    ) -> FeedSwipeDirection {
        if isHorizontalIntent(translation: translation),
           abs(translation.width) >= swipeCommitDistance {
            return direction(forHorizontalDistance: translation.width)
        }

        if isHorizontalIntent(translation: predictedEndTranslation),
           abs(predictedEndTranslation.width) >= predictedCommitDistance {
            return direction(forHorizontalDistance: predictedEndTranslation.width)
        }

        return .none
    }

    static func isHorizontalIntent(translation: CGSize) -> Bool {
        let dx = abs(translation.width)
        let dy = abs(translation.height)
        return dx >= horizontalIntentDistance && dx > dy * horizontalDominanceRatio
    }

    static func shouldSuppressTapAfterGesture(translation: CGSize) -> Bool {
        isHorizontalIntent(translation: translation)
    }

    private static func direction(forHorizontalDistance distance: CGFloat) -> FeedSwipeDirection {
        distance > 0 ? .previous : .next
    }
}
