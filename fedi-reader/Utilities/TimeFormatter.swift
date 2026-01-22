//
//  TimeFormatter.swift
//  fedi-reader
//
//  Helper for formatting relative time without seconds if under a minute
//

import Foundation

struct TimeFormatter {
    static func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        // If less than 60 seconds, show "now" or "just now"
        if timeInterval < 60 {
            return "now"
        }
        
        // Use DateFormatter for relative time, but format to remove seconds
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        
        let relativeString = formatter.localizedString(for: date, relativeTo: now)
        
        // Remove seconds from the string if present (e.g., "30 seconds ago" -> "30s ago")
        // But keep minutes, hours, days, etc.
        if timeInterval < 3600 { // Less than an hour
            // For times under an hour, ensure we show minutes, not seconds
            if relativeString.range(of: "sec", options: .caseInsensitive) != nil {
                // Replace "X sec ago" with "now" or "1m ago"
                let minutes = Int(timeInterval / 60)
                if minutes < 1 {
                    return "now"
                } else {
                    return "\(minutes)m"
                }
            }
        }
        
        return relativeString
    }
}
