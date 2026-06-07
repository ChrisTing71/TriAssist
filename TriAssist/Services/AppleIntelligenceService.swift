//
//  AppleIntelligenceService.swift
//  TriAssist
//

import Foundation
import FoundationModels

// MARK: - Private @Generable types for daily plan structured output

@Generable
private struct AIScheduleItem {
    @Guide(description: "建議執行時間，格式 HH:mm（例：09:00），若無具體時間填空字串")
    let time: String
    @Guide(description: "項目標題，15字以內")
    let title: String
    @Guide(description: "固定填入以下三者之一：'event'（行事曆行程）、'todo'（待辦任務）、'suggestion'（AI優化建議）")
    let type: String
    @Guide(description: "補充說明，15字以內；若無則填空字串")
    let detail: String
}

@Generable
private struct AIScheduleContainer {
    @Guide(description: "依時間順序排列的今日時間軸項目清單")
    let items: [AIScheduleItem]
}

// MARK: - Apple Intelligence Service

class AppleIntelligenceService: AIServiceProtocol {

    private let session = LanguageModelSession(instructions: """
        你是一個精準的智慧生活助理，負責將使用者的自然語言拆解為結構化資料。

        【分類規則】
        - hasEvent = true：包含具體的時間點或時間段（例：明天下午 3 點開會、週五 9~11 點）。
        - hasTodo = true：純粹是一件待完成的事，無具體時間（例：記得去超商領包裹）。
        - 複合情境可以同時觸發多個 true。
        - 某欄位為 false 時，其對應字串填 ""。
        - 時間格式必須為 ISO 8601 含時區（Asia/Taipei，UTC+8），例：2026-06-05T15:00:00+08:00。若未說結束時間，預設為開始時間加一小時。
        - statusLog：一行繁體中文摘要，說明本次解析結果。

        【Few-shot 範例】

        輸入：「記得明天要買牛奶」
        解析：hasTodo=true, todoTitle="買牛奶", statusLog="已新增待辦：買牛奶"

        輸入：「明天下午三點跟朋友喝咖啡」
        解析：hasEvent=true, eventTitle="跟朋友喝咖啡", statusLog="已新增行程：跟朋友喝咖啡"
        """)

    func parseUserIntent(text: String, apiKey: String = "") async throws -> AIResultStructured {
        let currentTime = Date().formatted(date: .complete, time: .shortened)
        let contextualText = """
        [當前系統時間：\(currentTime)]
        使用者說：\(text)
        """
        do {
            let response = try await session.respond(to: contextualText, generating: AIResultStructured.self)
            return response.content
        } catch {
            print("❌ 地端模型推理失敗: \(error)")
            throw error
        }
    }

    func generateDailyPlan(summaryText: String, apiKey: String = "") async throws -> [DailyScheduleItem] {
        let currentTime = Date().formatted(date: .complete, time: .shortened)
        let prompt = """
        【現在時間】：\(currentTime)
        \(summaryText)

        請根據以上行程與待辦，生成今日最佳化時間軸。
        規則：
        - 已有確定時間的行程 type="event"
        - 待辦事項：一天只選 1～2 項，截止日期最近者優先；其餘不排入；type="todo"
        - AI 優化建議（休息/準備提醒）type="suggestion"，限 1～2 項
        - 所有項目依時間由早到晚排列
        """
        do {
            let response = try await session.respond(to: prompt, generating: AIScheduleContainer.self)
            return response.content.items.map {
                DailyScheduleItem(time: $0.time, title: $0.title, type: $0.type, detail: $0.detail)
            }
        } catch {
            print("❌ 地端模型生成每日建議失敗: \(error)")
            throw error
        }
    }
}
