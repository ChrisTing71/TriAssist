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
        - hasEvent = true：包含具體的時間點或時間段（例：明天下午 3 點開會、週五 9~11 點）。
        - hasShoppingItem = true：明確要「購買某樣物品」（例：要買牛奶、買洗髮精、添購衛生紙）。shoppingItemName 填物品名稱，shoppingItemQuantity 填數量（無則填 ""）。
        - hasTodo = true：需要完成的任務，且不是「買東西」，也沒有具體時間（例：記得去超商領包裹、繳電話費）。
        - 複合情境可同時觸發多個 true。某欄位為 false 時，對應字串填 ""。
        - 時間格式：ISO 8601 含時區（例：2026-06-05T15:00:00+08:00）；未說時間預設 09:00；未說結束時間預設加一小時。
        - statusLog：一行繁體中文摘要。

        【Few-shot 範例】

        輸入：「明天下午三點跟朋友喝咖啡」
        輸出：{"hasEvent":true,"eventTitle":"跟朋友喝咖啡","eventStartISO":"<明天T15:00:00+08:00>","eventEndISO":"<明天T16:00:00+08:00>","hasShoppingItem":false,"shoppingItemName":"","shoppingItemQuantity":"","hasTodo":false,"todoTitle":"","statusLog":"已新增行程：跟朋友喝咖啡"}

        輸入：「要買牛奶兩瓶」
        輸出：{"hasEvent":false,"eventTitle":"","eventStartISO":"","eventEndISO":"","hasShoppingItem":true,"shoppingItemName":"牛奶","shoppingItemQuantity":"兩瓶","hasTodo":false,"todoTitle":"","statusLog":"已加入購物清單：牛奶 x 兩瓶"}

        輸入：「記得去超商領包裹」
        輸出：{"hasEvent":false,"eventTitle":"","eventStartISO":"","eventEndISO":"","hasShoppingItem":false,"shoppingItemName":"","shoppingItemQuantity":"","hasTodo":true,"todoTitle":"去超商領包裹","statusLog":"已新增待辦：去超商領包裹"}

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
        - 待辦事項：**一天只選 1～2 項排入時間軸**，以截止日期最近者優先；其餘待辦不必排入；type="todo"
        - AI 優化建議（休息、準備提醒等）：type="suggestion"，限 1～2 項
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
