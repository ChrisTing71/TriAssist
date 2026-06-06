//
//  CloudAIService.swift
//  TriAssist
//

import Foundation

class CloudAIService: AIServiceProtocol {

    // MARK: - Parse user intent → structured fields
    func parseUserIntent(text: String, apiKey: String) async throws -> AIResultStructured {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)") else {
            throw URLError(.badURL)
        }
        let currentTime = Date().formatted(date: .complete, time: .shortened)

        let systemInstruction = """
        你是一個精準的智慧生活助理，負責將使用者的自然語言拆解為結構化 JSON 資料。
        【當下系統基準時間】：\(currentTime)（時區：Asia/Taipei，UTC+8）

        【分類規則】
        - hasExpense = true：使用者明確提到金額或花費（例：花了 150、買便當 80 元）。
        - hasEvent = true：包含具體的時間點或時間段（例：明天下午 3 點開會、週五 9~11 點）。
        - hasTodo = true：純粹是一件待完成的事，無具體時間也無金額（例：記得去超商領包裹）。
        - 複合情境可以同時觸發多個 true。
        - 某欄位為 false 時，其對應字串填 ""，金額填 0。
        - 時間格式必須為 ISO 8601 含時區（例：2026-06-05T15:00:00+08:00）；若只說日期未說時間，預設 09:00；若未說結束時間，預設為開始時間加一小時。
        - statusLog：一行繁體中文摘要，說明本次解析結果。

        【Few-shot 範例】

        輸入：「明天下午三點跟朋友喝咖啡花了 150 元」
        輸出：{"hasExpense":true,"expenseItem":"咖啡","expenseAmount":150,"expenseCategory":"餐飲","hasEvent":true,"eventTitle":"跟朋友喝咖啡","eventStartISO":"<明天T15:00:00+08:00>","eventEndISO":"<明天T16:00:00+08:00>","hasTodo":false,"todoTitle":"","statusLog":"已新增行程：跟朋友喝咖啡；花費：咖啡 150 元"}

        輸入：「記得明天要買牛奶」
        輸出：{"hasExpense":false,"expenseItem":"","expenseAmount":0,"expenseCategory":"","hasEvent":false,"eventTitle":"","eventStartISO":"","eventEndISO":"","hasTodo":true,"todoTitle":"買牛奶","statusLog":"已新增待辦：買牛奶"}

        輸入：「今天午餐花了 85 元吃便當」
        輸出：{"hasExpense":true,"expenseItem":"便當","expenseAmount":85,"expenseCategory":"餐飲","hasEvent":false,"eventTitle":"","eventStartISO":"","eventEndISO":"","hasTodo":false,"todoTitle":"","statusLog":"已記帳：便當 85 元"}

        你必須只回傳一個 JSON 物件，不得包含任何說明、註解或 Markdown 標籤。
        """

        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": text]]]
            ],
            "systemInstruction": [
                "parts": [["text": systemInstruction]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        struct GeminiResponse: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    struct Part: Codable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let apiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let jsonString = apiResponse.candidates.first?.content.parts.first?.text,
              let jsonData = jsonString.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }

        return try JSONDecoder().decode(AIResultStructured.self, from: jsonData)
    }

    // MARK: - Generate daily plan → structured timeline items
    func generateDailyPlan(summaryText: String, apiKey: String) async throws -> [DailyScheduleItem] {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)") else {
            throw URLError(.badURL)
        }
        let currentTime = Date().formatted(date: .complete, time: .shortened)

        let prompt = """
        【現在時間】：\(currentTime)（時區：Asia/Taipei，UTC+8）
        \(summaryText)

        請根據以上行程與待辦，生成一個今日最佳化時間軸，以 JSON 陣列回傳。
        每個項目格式：{"time":"HH:mm","title":"標題","type":"event|todo|suggestion","detail":"補充說明"}

        規則：
        - 已有確定時間的行程：type="event"，填入具體時間
        - 待辦事項排入合適空檔：type="todo"，填入建議執行時間
        - AI 優化建議（休息、準備提醒等）：type="suggestion"
        - 所有項目依時間由早到晚排列
        - detail 限 15 字以內；若無補充則填 ""
        - 只回傳 JSON 陣列，禁止任何其他文字或 Markdown
        """

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        struct GeminiTextResponse: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    struct Part: Codable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let apiResponse = try JSONDecoder().decode(GeminiTextResponse.self, from: data)
        guard let jsonString = apiResponse.candidates.first?.content.parts.first?.text,
              let jsonData = jsonString.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }

        return (try? JSONDecoder().decode([DailyScheduleItem].self, from: jsonData)) ?? []
    }
}
