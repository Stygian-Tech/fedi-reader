//
//  ToggleActionCountTests.swift
//  fedi-readerTests
//

import Testing
@testable import fedi_reader

@Suite("Toggle Action Count Tests")
struct ToggleActionCountTests {
    @Test("Optimistic decrement clamps at zero")
    func optimisticDecrementClampsAtZero() {
        let count = ToggleActionCount.optimistic(currentCount: 0, wasActive: true)
        #expect(count == 0)
    }

    @Test("Optimistic increment adds one")
    func optimisticIncrementAddsOne() {
        let count = ToggleActionCount.optimistic(currentCount: 7, wasActive: false)
        #expect(count == 8)
    }

    @Test("Reconciled uses optimistic count when un-toggle server count is stale")
    func reconciledUsesOptimisticForStaleUntoggleCount() {
        let count = ToggleActionCount.reconciled(
            originalCount: 10,
            wasActive: true,
            serverCount: 10,
            serverIsActive: false
        )
        #expect(count == 9)
    }

    @Test("Reconciled uses server count when un-toggle server count is fresh")
    func reconciledUsesServerForFreshUntoggleCount() {
        let count = ToggleActionCount.reconciled(
            originalCount: 10,
            wasActive: true,
            serverCount: 9,
            serverIsActive: false
        )
        #expect(count == 9)
    }

    @Test("Reconciled uses optimistic count when toggle-on server count is stale")
    func reconciledUsesOptimisticForStaleToggleOnCount() {
        let count = ToggleActionCount.reconciled(
            originalCount: 10,
            wasActive: false,
            serverCount: 10,
            serverIsActive: true
        )
        #expect(count == 11)
    }

    @Test("Reconciled uses server count when server state is unexpected")
    func reconciledUsesServerForUnexpectedServerState() {
        let count = ToggleActionCount.reconciled(
            originalCount: 10,
            wasActive: true,
            serverCount: 12,
            serverIsActive: true
        )
        #expect(count == 12)
    }
}
