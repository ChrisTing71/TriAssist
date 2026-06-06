//
//  RoutineModels.swift
//  TriAssist
//

import Foundation

// Minutes since midnight (0–1439), used to represent a time-of-day
typealias MinuteOfDay = Int

extension MinuteOfDay {
    var timeString: String {
        String(format: "%02d:%02d", self / 60, self % 60)
    }
}

// A single recurring weekly event (class, shift, etc.)
struct RecurringEvent: Codable, Identifiable {
    var id = UUID()
    var name: String
    var weekdays: [Int]      // 0=Mon … 6=Sun
    var startMinutes: MinuteOfDay
    var endMinutes: MinuteOfDay

    static let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    var weekdayDisplay: String {
        weekdays.sorted().map { Self.weekdayLabels[$0] }.joined(separator: "")
    }

    // Returns true if this event occurs on the given weekday (0=Mon…6=Sun)
    func occursOn(_ weekday: Int) -> Bool { weekdays.contains(weekday) }
}
