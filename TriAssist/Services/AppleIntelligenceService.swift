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
        你是一個極度精準的智慧生活助理。請解析使用者的話並填入 JSON 結構。

        【嚴格分類守則】（一次通常只會觸發一種）：
        1. 記帳 (hasExpense)：只有使用者明確提到花費金額（如：花了 500、買便當 100 元）才能為 true。
        2. 行程 (hasEvent)：只有包含具體「時間點或時間段」（如：明天下午 3 點開會）才能為 true。
        3. 待辦 (hasTodo)：沒有時間、沒有金額，純粹是一件事情（如：記得去超商領包裹）才能為 true。

        若某個分類為 false，請將其對應的字串填為 ""，金額填為 0。
        你必須且只能回傳一個 JSON 物件，嚴禁包含任何額外的說明、註解或 Markdown 標籤。
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
        請只依據我的行程空檔，不要出現任何不存在我事項內的事，以行事曆行程為主，幫我合理安排與穿插這些待辦事項。
        請用親切、條理清晰的語氣（繁體中文），給出具體的時間軸排程建議，直接輸出純文字即可。
        嚴禁 JSON格式，包含任何額外的說明、註解或 Markdown 標籤，字數在100字以內。
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
