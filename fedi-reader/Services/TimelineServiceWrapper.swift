//
//  TimelineServiceWrapper.swift
//  fedi-reader
//
//  Observable wrapper for TimelineService used with SwiftUI environment.
//

import Foundation

@Observable
@MainActor
final class TimelineServiceWrapper {
    var service: TimelineService?

    init(service: TimelineService? = nil) {
        self.service = service
    }
}
