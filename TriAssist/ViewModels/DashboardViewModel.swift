//
//  DashboardViewModel.swift
//  TriAssist
//

import SwiftUI
import SwiftData
import FoundationModels

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

    // Daily schedule timeline items
    var scheduleItems: [DailyScheduleItem] = []
    var isLoadingBriefing = false
    var briefingMessage = ""   // shown when scheduleItems is empty

    // Fixed routine summary injected from RoutineManager before each load
    var routineSummary: String = ""

    // Brief result feedback after user submits text
    var lastActionResult = ""
    private var resultDismissTask: Task<Void, Never>?

    private var hasLoadedBriefing = false

    init() {
        if let savedString = UserDefaults.standard.string(forKey: "selectedAIEngine"),
           let engine = AIEngine(rawValue: savedString) {
            self.selectedEngine = engine
        }
        self.apiKey = UserDefaults.standard.string(forKey: "customApiKey") ?? ""
    }

    private var aiService: AIServiceProtocol {
        selectedEngine == .cloud ? CloudAIService() : AppleIntelligenceService()
    }

    // MARK: - Load daily briefing
    func loadDailyBriefing(modelContext: ModelContext, forceRefresh: Bool = false) async {
        guard !hasLoadedBriefing || forceRefresh else { return }
        hasLoadedBriefing = true

        withAnimation {
            isLoadingBriefing = true
            briefingMessage = ""
            if forceRefresh { scheduleItems = [] }
        }

        let today = Date()
        let allEvents = (try? modelContext.fetch(FetchDescriptor<Event>())) ?? []
        let allTodos = (try? modelContext.fetch(FetchDescriptor<TodoTask>())) ?? []

        let todayEvents = allEvents.filter { Calendar.current.isDate($0.startTime, inSameDayAs: today) }
        let activeTodos = allTodos.filter { !$0.isCompleted }

        guard !todayEvents.isEmpty || !activeTodos.isEmpty else {
            withAnimation {
                isLoadingBriefing = false
                briefingMessage = "今天目前沒有行程與待辦任務，跟我說說你今天的計畫吧！"
            }
            return
        }

        let eventSummary = todayEvents.isEmpty
            ? "無行程"
            : todayEvents.map { " - \($0.title) (\($0.startTime.formatted(date: .omitted, time: .shortened)) ~ \($0.endTime.formatted(date: .omitted, time: .shortened)))" }.joined(separator: "\n")

        let todoSummary = activeTodos.isEmpty
            ? "無待辦事項"
            : activeTodos.map { " - \($0.title)" }.joined(separator: "\n")

        let routineSection = routineSummary.isEmpty ? "" : """
        【固定行程】：\(routineSummary)

        """

        let summaryText = """
        \(routineSection)我今天的行程如下：
        \(eventSummary)

        我的待辦清單如下：
        \(todoSummary)
        """

        do {
            let items = try await aiService.generateDailyPlan(summaryText: summaryText, apiKey: apiKey)
            withAnimation {
                scheduleItems = items
                isLoadingBriefing = false
                briefingMessage = items.isEmpty ? "AI 無法生成排程建議，請稍後再試。" : ""
            }
        } catch {
            withAnimation {
                isLoadingBriefing = false
                briefingMessage = "排程建議載入失敗，請檢查網路或 API Key 設定。"
            }
        }
    }

    // MARK: - Handle user text/voice input
    func handleUserVoiceOrTextInput(modelContext: ModelContext) async {
        let cleanText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        if selectedEngine == .apple && SystemLanguageModel.default.availability != .available {
            showAIUnavailableAlert = true
            return
        }

        withAnimation { isProcessing = true }

        do {
            let result = try await aiService.parseUserIntent(text: cleanText, apiKey: apiKey)
            let formatter = ISO8601DateFormatter()

            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                if result.hasExpense && result.expenseAmount > 0 {
                    let newExpense = Expense(
                        item: result.expenseItem.isEmpty ? "未命名消費" : result.expenseItem,
                        amount: result.expenseAmount,
                        category: result.expenseCategory.isEmpty ? "未分類" : result.expenseCategory
                    )
                    modelContext.insert(newExpense)
                }

                if result.hasEvent && !result.eventTitle.isEmpty {
                    let start = formatter.date(from: result.eventStartISO) ?? Date()
                    let end = formatter.date(from: result.eventEndISO) ?? start.addingTimeInterval(3600)
                    modelContext.insert(Event(title: result.eventTitle, startTime: start, endTime: end))
                }

                if result.hasTodo && !result.todoTitle.isEmpty {
                    modelContext.insert(TodoTask(title: result.todoTitle))
                }

                inputText = ""
            }

            // Show result feedback and auto-dismiss after 3 seconds
            if !result.statusLog.isEmpty {
                showResult(result.statusLog)
            }

            // Refresh briefing to reflect newly added items
            if result.hasEvent || result.hasTodo {
                Task {
                    await loadDailyBriefing(modelContext: modelContext, forceRefresh: true)
                }
            }

        } catch {
            print("❌ 核心管家分流失敗: \(error.localizedDescription)")
        }

        withAnimation { isProcessing = false }
    }

    private func showResult(_ message: String) {
        resultDismissTask?.cancel()
        withAnimation { lastActionResult = message }
        resultDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation { lastActionResult = "" }
        }
    }
}
