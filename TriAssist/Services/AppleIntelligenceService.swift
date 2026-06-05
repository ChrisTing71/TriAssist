//
//  AppleIntelligenceService.swift
//  TriAssist
//
//  Created by 丁帥 on 2026/6/4.
//

import Foundation
import FoundationModels // 導入簡報採用的 Apple 官方 On-device AI 框架

class AppleIntelligenceService: AIServiceProtocol {
    // 建立會話，並依據簡報第 63 頁指示，在系統最高層級注入系統原則與目前時間基準
    private let session = LanguageModelSession(instructions: """
        你是一個精準的智慧生活助理，負責將使用者的自然語言拆解為結構化資料。

        【分類規則】
        - hasExpense = true：使用者明確提到金額或花費（例：花了 150、買便當 80 元）。
        - hasEvent = true：包含具體的時間點或時間段（例：明天下午 3 點開會、週五 9~11 點）。
        - hasTodo = true：純粹是一件待完成的事，無具體時間也無金額（例：記得去超商領包裹）。
        - 複合情境可以同時觸發多個 true（例：「明天下午三點喝咖啡花了 150 元」→ hasEvent=true 且 hasExpense=true）。
        - 某欄位為 false 時，其對應字串填 ""，金額填 0。
        - 時間格式必須為 ISO 8601 含時區（Asia/Taipei，UTC+8），例：2026-06-05T15:00:00+08:00。若未說結束時間，預設為開始時間加一小時。
        - statusLog：一行人類可讀的摘要，說明本次解析結果。

        【Few-shot 範例】

        輸入：「記得明天要買牛奶」
        解析：hasTodo=true, todoTitle="買牛奶", statusLog="已新增待辦：買牛奶"

        輸入：「今天午餐花了 85 元吃便當」
        解析：hasExpense=true, expenseItem="便當", expenseAmount=85, expenseCategory="餐飲", statusLog="已記帳：便當 85 元"

        輸入：「明天下午三點跟朋友喝咖啡花了 150 元」
        解析：hasEvent=true 且 hasExpense=true 同時觸發（複合情境）
        """)
    
    func parseUserIntent(text: String, apiKey: String = "") async throws -> AIResultStructured {
        // 🌟 1. 動態取得當下時間
        let currentTime = Date().formatted(date: .complete, time: .shortened)
        
        // 🌟 2. 偷偷將時間與使用者的話包裝在一起送給地端模型
        let contextualText = """
        [當前系統時間：\(currentTime)]
        使用者說：\(text)
        """
        
        do {
            let response = try await session.respond(
                to: contextualText, // 👈 傳入包裝好的文字
                generating: AIResultStructured.self
            )
            return response.content
        } catch {
            print("❌ 地端模型推理失敗: \(error)")
            throw error
        }
    }
    
    func generateDailyPlan(summaryText: String, apiKey: String = "") async throws -> String {
        // 🌟 3. 動態取得當下時間
        let currentTime = Date().formatted(date: .complete, time: .shortened)
        
        let prompt = """
        【現在時間】：\(currentTime)
        \(summaryText)

        請以行事曆行程為錨點，在空檔中合理穿插待辦事項，只使用上方列出的事項，不得自行添加。
        要求：繁體中文、親切語氣、純文字（禁止 JSON 或 Markdown）、100 字以內。
        """
        
        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            print("❌ 地端模型生成每日建議失敗: \(error)")
            throw error
        }
    }
}
