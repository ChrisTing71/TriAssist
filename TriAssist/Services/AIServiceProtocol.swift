//
//  AIServiceProtocol.swift
//  TriAssist
//

import Foundation
import FoundationModels

// Structured output for user intent parsing
@Generable
struct AIResultStructured: Codable {
    @Guide(description: "只有明確提到『特定的時間段、開會、約會、活動』時才為 true。若只是一般任務請標為 false。")
    let hasEvent: Bool
    let eventTitle: String
    let eventStartISO: String
    let eventEndISO: String

    @Guide(description: "只有這是一件『需要被完成的任務』且沒有具體執行時間時才為 true。")
    let hasTodo: Bool
    let todoTitle: String

    @Guide(description: "一行繁體中文摘要，說明本次解析了什麼（例：已新增行程：牙醫回診）")
    let statusLog: String
}

// Structured item for daily schedule timeline
struct DailyScheduleItem: Codable, Identifiable {
    let time: String    // "HH:mm" or "" if unscheduled
    let title: String
    let type: String    // "event" | "todo" | "suggestion"
    let detail: String  // short subtitle, may be ""

    var id: String { "\(time)-\(title)" }

    init(time: String, title: String, type: String, detail: String) {
        self.time = time
        self.title = title
        self.type = type
        self.detail = detail
    }

    enum CodingKeys: String, CodingKey {
        case time, title, type, detail
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        time   = try c.decode(String.self, forKey: .time)
        title  = try c.decode(String.self, forKey: .title)
        type   = try c.decode(String.self, forKey: .type)
        detail = (try? c.decode(String.self, forKey: .detail)) ?? ""
    }
}

// Service protocol
protocol AIServiceProtocol {
    func parseUserIntent(text: String, apiKey: String) async throws -> AIResultStructured
    func generateDailyPlan(summaryText: String, apiKey: String) async throws -> [DailyScheduleItem]
}
