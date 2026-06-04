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
        你是一個極度精準的智慧生活助理。請解析使用者的話並填入 JSON 結構。
        【當下系統基準時間】：\(currentTime) 

        【嚴格分類守則】（一次通常只會觸發一種）：
        1. 記帳 (hasExpense)：只有使用者明確提到花費金額（如：花了 500、買便當 100 元）才能為 true。
        2. 行程 (hasEvent)：只有包含具體「時間點或時間段」（如：明天下午 3 點開會）才能為 true。
        3. 待辦 (hasTodo)：沒有時間、沒有金額，純粹是一件事情（如：記得去超商領包裹）才能為 true。

        若某個分類為 false，請將其對應的字串填為 ""，金額填為 0。
        你必須且只能回傳一個 JSON 物件，嚴禁包含任何額外的說明、註解或 Markdown 標籤。
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
        請只依據我的行程空檔，以行事曆行程為主，幫我合理安排與穿插這些待辦事項。
        請用親切、條理清晰的語氣（繁體中文），給出具體的時間軸排程建議，直接輸出純文字建議即可。ｘ
        嚴禁包含任何額外的說明、註解或 Markdown 標籤，字數在100字以內。
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
