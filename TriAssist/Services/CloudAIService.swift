//
//  CloudAIService.swift
//  TriAssist
//
//  Created by 丁帥 on 2026/6/4.
//

import Foundation

import Foundation

class CloudAIService: AIServiceProtocol {
    func parseUserIntent(text: String, apiKey: String) async throws -> AIResultStructured {
        // 1. 設定 Google Gemini 官方最新大模型的 API 網址 (此處以 gemini-2.5-flash 為例)
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
        - 複合情境可以同時觸發多個 true（例：「明天下午三點喝咖啡花了 150 元」→ hasEvent=true 且 hasExpense=true）。
        - 某欄位為 false 時，其對應字串填 ""，金額填 0。
        - 時間格式必須為 ISO 8601 含時區（例：2026-06-05T15:00:00+08:00）；若只說日期未說時間，預設 09:00；若未說結束時間，預設為開始時間加一小時。
        - statusLog：一行人類可讀的摘要，說明本次解析結果（例：「已新增行程：牙醫回診；花費：掛號費 150 元」）。

        【Few-shot 範例】

        輸入：「明天下午三點跟朋友喝咖啡花了 150 元」
        輸出：{"hasExpense":true,"expenseItem":"咖啡","expenseAmount":150,"expenseCategory":"餐飲","hasEvent":true,"eventTitle":"跟朋友喝咖啡","eventStartISO":"<明天T15:00:00+08:00>","eventEndISO":"<明天T16:00:00+08:00>","hasTodo":false,"todoTitle":"","statusLog":"已新增行程：跟朋友喝咖啡；花費：咖啡 150 元"}

        輸入：「記得明天要買牛奶」
        輸出：{"hasExpense":false,"expenseItem":"","expenseAmount":0,"expenseCategory":"","hasEvent":false,"eventTitle":"","eventStartISO":"","eventEndISO":"","hasTodo":true,"todoTitle":"買牛奶","statusLog":"已新增待辦：買牛奶"}

        輸入：「今天午餐花了 85 元吃便當」
        輸出：{"hasExpense":true,"expenseItem":"便當","expenseAmount":85,"expenseCategory":"餐飲","hasEvent":false,"eventTitle":"","eventStartISO":"","eventEndISO":"","hasTodo":false,"todoTitle":"","statusLog":"已記帳：便當 85 元"}

        你必須只回傳一個 JSON 物件，不得包含任何說明、註解或 Markdown 標籤。
        """
        
        // 3. 依據 Google 官方規範，建立強制的結構化 JSON 輸出設定 (Response Schema)
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": text]]]
            ],
            "systemInstruction": [
                "parts": [["text": systemInstruction]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json" // 👈 強制要求 Gemini 吐出標準 JSON
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 4. 發送請求並非同步等待回應
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // 5. 解析 Google Gemini 特有的巢狀 JSON 回傳結構
        struct GeminiResponse: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    struct Part: Codable {
                        let text: String
                    }
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
        
        // 6. 完美解碼，轉換為我們 App 原生的 AIResultStructured 強型別資料
        return try JSONDecoder().decode(AIResultStructured.self, from: jsonData)
    }
    // 在 CloudAIService.swift 中補上實作
    func generateDailyPlan(summaryText: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)") else {
            throw URLError(.badURL)
        }
        let currentTime = Date().formatted(date: .complete, time: .shortened)
        
        let prompt = """
        【現在時間】：\(currentTime)
        \(summaryText)

        請以行事曆行程為錨點，在空檔中合理穿插待辦事項，給出具體的時間軸建議。
        要求：繁體中文、親切語氣、純文字（禁止 JSON 或 Markdown）、100 字以內。
        """
        
        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
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
        return apiResponse.candidates.first?.content.parts.first?.text ?? "無法生成今日優化建議。"
    }
}
