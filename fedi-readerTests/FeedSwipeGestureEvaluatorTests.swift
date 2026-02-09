//
//  FeedSwipeGestureEvaluatorTests.swift
//  fedi-readerTests
//
//  Unit tests for feed swipe gesture heuristics.
//

import CoreGraphics
import Testing
@testable import fedi_reader

@Suite("Feed Swipe Gesture Evaluator Tests")
struct FeedSwipeGestureEvaluatorTests {

    @Test("Commits previous feed from direct translation threshold")
    func commitsPreviousFromTranslationThreshold() {
        let direction = FeedSwipeGestureEvaluator.shouldCommit(
            translation: CGSize(width: 64, height: 4),
            predictedEndTranslation: CGSize(width: 70, height: 4)
        )
        #expect(direction == .previous)
    }

    @Test("Commits next feed from predicted end threshold")
    func commitsNextFromPredictedThreshold() {
        let direction = FeedSwipeGestureEvaluator.shouldCommit(
            translation: CGSize(width: -28, height: 3),
            predictedEndTranslation: CGSize(width: -92, height: 3)
        )
        #expect(direction == .next)
    }

    @Test("Does not commit when movement is not horizontal intent")
    func doesNotCommitForVerticalDominantGesture() {
        let direction = FeedSwipeGestureEvaluator.shouldCommit(
            translation: CGSize(width: 60, height: 64),
            predictedEndTranslation: CGSize(width: 100, height: 120)
        )
        #expect(direction == .none)
    }

    @Test("Visual offset uses resistance and clamp")
    func visualOffsetResistsAndClamps() {
        let resisted = FeedSwipeGestureEvaluator.visualOffset(translation: CGSize(width: 40, height: 0))
        let clamped = FeedSwipeGestureEvaluator.visualOffset(translation: CGSize(width: 400, height: 0))

        #expect(abs(resisted - 14) < 0.001)
        #expect(clamped == FeedSwipeGestureEvaluator.maxVisualOffset)
    }

    @Test("Visual offset is zero when no horizontal intent")
    func visualOffsetZeroWithoutHorizontalIntent() {
        let tiny = FeedSwipeGestureEvaluator.visualOffset(translation: CGSize(width: 2, height: 0))
        let vertical = FeedSwipeGestureEvaluator.visualOffset(translation: CGSize(width: 10, height: 24))

        #expect(tiny == 0)
        #expect(vertical == 0)
    }

    @Test("Horizontal intent threshold is strict and deterministic")
    func horizontalIntentThreshold() {
        #expect(FeedSwipeGestureEvaluator.isHorizontalIntent(translation: CGSize(width: 10, height: 0)))
        #expect(!FeedSwipeGestureEvaluator.isHorizontalIntent(translation: CGSize(width: 9.9, height: 0)))
        #expect(!FeedSwipeGestureEvaluator.isHorizontalIntent(translation: CGSize(width: 10, height: 10)))
    }

    @Test("Suppression is enabled for swipe-like gestures")
    func suppressesTapAfterSwipeLikeGesture() {
        #expect(FeedSwipeGestureEvaluator.shouldSuppressTapAfterGesture(translation: CGSize(width: 12, height: 2)))
        #expect(!FeedSwipeGestureEvaluator.shouldSuppressTapAfterGesture(translation: CGSize(width: 2, height: 1)))
    }
}
