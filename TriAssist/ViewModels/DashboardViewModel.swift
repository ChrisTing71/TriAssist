//
//  DashboardViewModel.swift
//  TriAssist
//
//  Created by 丁帥 on 2026/6/4.
//

import SwiftUI
import SwiftData
import FoundationModels // 引入以檢查系統 AI 可用性

enum AIEngine: String, CaseIterable {
    case cloud = "雲端高效能 AI"
    case apple = "Apple Intelligence地端隱私"
}

@MainActor
@Observable
class DashboardViewModel {
    var selectedEngine: AIEngine = .cloud
    var apiKey: String = ""
    var isProcessing = false
    var inputText = ""
    var showAIUnavailableAlert = false
    
    // 存放 AI 優化後的行程建議文字
    var aiSuggestion: String = "正在為您準備今日的日程優化建議..."
    // 防止重複觸發的旗標
    private var hasLoadedBriefing = false
    
    init() {
        if let savedEngineString = UserDefaults.standard.string(forKey: "selectedAIEngine"),
           let engine = AIEngine(rawValue: savedEngineString) {
            self.selectedEngine = engine
        }
        self.apiKey = UserDefaults.standard.string(forKey: "customApiKey") ?? ""
    }
    
    private var aiService: AIServiceProtocol {
        selectedEngine == .cloud ? CloudAIService() : AppleIntelligenceService()
    }
    
    // 🌟 優化：自動讀取今天資料並向 AI 請求優化（整合 forceRefresh 支援重試）
    func loadDailyBriefing(modelContext: ModelContext, forceRefresh: Bool = false) async {
        // 除非是強制刷新，否則若已經載入過就直接返回，防止切換 Tab 重複觸發
        guard !hasLoadedBriefing || forceRefresh else { return }
        hasLoadedBriefing = true
        
        // 如果是使用者手動點擊重試，先給予文字畫面的即時回饋
        if forceRefresh {
            withAnimation {
                self.aiSuggestion = "正在為您重新整理今日的日程建議..."
            }
        }
        
        let today = Date()
        let allEvents = (try? modelContext.fetch(FetchDescriptor<Event>())) ?? []
        let allTodos = (try? modelContext.fetch(FetchDescriptor<TodoTask>())) ?? []
        
        let todayEvents = allEvents.filter { Calendar.current.isDate($0.startTime, inSameDayAs: today) }
        let activeTodos = allTodos.filter { !$0.isCompleted }
        
        if todayEvents.isEmpty && activeTodos.isEmpty {
            self.aiSuggestion = "您今天目前沒有任何行程與待辦任務，點擊下方跟我聊天來新增吧！"
            return
        }
        
        // 在 MainActor 執行緒內把資料轉化為純文字 String (Sendable)
        let eventSummary = todayEvents.isEmpty ? "無行程" : todayEvents.map { " - \($0.title) (\($0.startTime.formatted(date: .omitted, time: .shortened)) ~ \($0.endTime.formatted(date: .omitted, time: .shortened)))" }.joined(separator: "\n")
        let todoSummary = activeTodos.isEmpty ? "無待辦事項" : activeTodos.map { " - \($0.title)" }.joined(separator: "\n")
        
        let summaryText = """
        我今天的行程如下：
        \(eventSummary)
        
        我的待辦清單如下：
        \(todoSummary)
        """
        
        do {
            // 傳遞 Sendable 的 String 變數，避開 Swift 6 檢查警告
            let recommendation = try await aiService.generateDailyPlan(summaryText: summaryText, apiKey: apiKey)
            withAnimation {
                self.aiSuggestion = recommendation
            }
        } catch {
            self.aiSuggestion = "今日日程排程失敗，請檢查網路或 API Key 設定。"
        }
    }
    
    // 4. 核心處理函式
    func handleUserVoiceOrTextInput(modelContext: ModelContext) async {
        let cleanText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        
        if selectedEngine == .apple && SystemLanguageModel.default.availability != .available {
            self.showAIUnavailableAlert = true
            return
        }
        
        withAnimation { self.isProcessing = true }
        
        do {
            let result = try await aiService.parseUserIntent(text: cleanText, apiKey: apiKey)
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                let formatter = ISO8601DateFormatter()
                
                if result.hasExpense && result.expenseAmount > 0 { // 雙重防呆
                    let newExpense = Expense(
                        item: result.expenseItem.isEmpty ? "未命名消費" : result.expenseItem,
                        amount: result.expenseAmount,
                        category: result.expenseCategory.isEmpty ? "未分類" : result.expenseCategory
                    )
                    modelContext.insert(newExpense)
                }

                if result.hasEvent && !result.eventTitle.isEmpty { // 防呆
                    let start = formatter.date(from: result.eventStartISO) ?? Date()
                    let end = formatter.date(from: result.eventEndISO) ?? Date().addingTimeInterval(3600)
                    let newEvent = Event(title: result.eventTitle, startTime: start, endTime: end)
                    modelContext.insert(newEvent)
                }

                if result.hasTodo && !result.todoTitle.isEmpty { // 防呆
                    let newTodo = TodoTask(title: result.todoTitle)
                    modelContext.insert(newTodo)
                }
                
                self.inputText = ""
            }
        } catch {
            print("❌ 核心管家分流失敗: \(error.localizedDescription)")
        }
        
        withAnimation { self.isProcessing = false }
    }
}
