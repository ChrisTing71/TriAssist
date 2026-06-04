//
//  AIServiceProtocol.swift
//  TriAssist
//
//  Created by 丁帥 on 2026/6/4.
//

import Foundation
import FoundationModels // 引入北科大課堂簡報教材採用的 AI 框架

// 配合簡報第 72-75 頁，使用 @Generable 將 AI 生成結果直接對應結構化型別
@Generable
struct AIResultStructured: Codable {
    // 🌟 優化 1：為 Boolean 加上嚴格判定條件
    @Guide(description: "只有使用者明確提到『金額、花費、買了什麼』時才為 true，否則絕對要是 false。")
    let hasExpense: Bool
    let expenseItem: String
    let expenseAmount: Double
    let expenseCategory: String
    
    @Guide(description: "只有明確提到『特定的時間段、開會、約會』時才為 true。若只是一般任務請標為 false。")
    let hasEvent: Bool
    let eventTitle: String
    let eventStartISO: String
    let eventEndISO: String
    
    @Guide(description: "只有這是一件『需要被完成的任務』且沒有具體執行時間與花費時才為 true。")
    let hasTodo: Bool
    let todoTitle: String
    
    @Guide(description: "Must be 'TRUE' or 'FALSE' based on user intent.")
    let statusLog: String
}

// 統一的 AI 接口
protocol AIServiceProtocol {
    func parseUserIntent(text: String, apiKey: String) async throws -> AIResultStructured
    func generateDailyPlan(summaryText: String, apiKey: String) async throws -> String
}
