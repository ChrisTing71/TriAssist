//
//  RoutineManager.swift
//  TriAssist
//

import Foundation

@MainActor
@Observable
class RoutineManager {

    // MARK: - Daily fixed times
    var hasWakeUp: Bool = true
    var wakeUpMinutes: MinuteOfDay = 7 * 60      // 07:00

    var hasSleep: Bool = true
    var sleepMinutes: MinuteOfDay = 23 * 60      // 23:00

    // MARK: - Weekly recurring events
    var recurringEvents: [RecurringEvent] = []

    // MARK: - Init
    init() { load() }

    // MARK: - Persistence
    func save() {
        UserDefaults.standard.set(hasWakeUp,     forKey: "routine.hasWakeUp")
        UserDefaults.standard.set(hasSleep,      forKey: "routine.hasSleep")
        UserDefaults.standard.set(wakeUpMinutes, forKey: "routine.wakeUpMinutes")
        UserDefaults.standard.set(sleepMinutes,  forKey: "routine.sleepMinutes")
        if let data = try? JSONEncoder().encode(recurringEvents) {
            UserDefaults.standard.set(data, forKey: "routine.events")
        }
    }

    private func load() {
        let ud = UserDefaults.standard
        if ud.object(forKey: "routine.hasWakeUp") != nil {
            hasWakeUp     = ud.bool(forKey: "routine.hasWakeUp")
            hasSleep      = ud.bool(forKey: "routine.hasSleep")
            wakeUpMinutes = ud.integer(forKey: "routine.wakeUpMinutes")
            sleepMinutes  = ud.integer(forKey: "routine.sleepMinutes")
        }
        if let data = ud.data(forKey: "routine.events"),
           let events = try? JSONDecoder().decode([RecurringEvent].self, from: data) {
            recurringEvents = events
        }
    }

    // MARK: - AI Summary
    var aiSummary: String {
        var parts: [String] = []

        if hasWakeUp { parts.append("起床 \(wakeUpMinutes.timeString)") }
        if hasSleep  { parts.append("睡覺 \(sleepMinutes.timeString)") }

        let todayWeekday = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
        let todayEvents = recurringEvents.filter { $0.occursOn(todayWeekday) }

        if !todayEvents.isEmpty {
            let descriptions = todayEvents.map {
                "\($0.name) \($0.startMinutes.timeString)–\($0.endMinutes.timeString)"
            }
            parts.append("今日固定：" + descriptions.joined(separator: "、"))
        }

        if !recurringEvents.isEmpty {
            let weekly = recurringEvents.map {
                "週\($0.weekdayDisplay) \($0.name) \($0.startMinutes.timeString)–\($0.endMinutes.timeString)"
            }
            parts.append("每週課表：" + weekly.joined(separator: "｜"))
        }

        return parts.isEmpty ? "" : parts.joined(separator: "，")
    }
}
