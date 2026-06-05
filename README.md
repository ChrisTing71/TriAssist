# 🌟 TriAssist  - 智慧生活管家

![iOS](https://img.shields.io/badge/iOS-17.0+-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square&logo=swift)
![Architecture](https://img.shields.io/badge/Architecture-MVVM-blue?style=flat-square)
![Database](https://img.shields.io/badge/Database-SwiftData-red?style=flat-square)

TriAssist 是一款結合前瞻人工智慧技術的全方位生活管理 iOS 應用程式。透過自然語言處理，使用者只需一句話即可自動完成「記帳」、「行程安排」與「待辦事項」的歸檔。系統更具備主動式的每日排程優化大腦，為您妥善穿插零碎任務。

---

## ✨ 核心特色 (Key Features)

* **雙 AI 引擎策略分流 (Dual AI Engine)**
  * **Apple Intelligence (地端)**: 整合 `FoundationModels` 框架，在設備端離線進行安全、隱私的意圖解析。
  * **Google Gemini 2.5 Flash (雲端)**: 提供高效能的自然語言結構化輸出 (Structured Outputs)。
* **智慧語意解析 (Intent Parsing)**
  * 支援自然對話輸入（例如：「明天下午三點要跟朋友喝咖啡花了 150 元」）。
  * 透過強型別定義與 AI 邊界防呆機制，精準分流至對應的資料庫模型。
* **主動式排程建議 (Smart Daily Briefing)**
  * 每日啟動時，自動撈取當日行程與未完成待辦，透過 AI 大模型運算最優化的時間軸排程。
  * 具備防刷機制與手動強制重載 (Force-refresh) 功能。
* **現代化本地存儲 (SwiftData)**
  * 採用 Apple 最新 SwiftData 框架，實現 `Expense`、`Event`、`TodoTask` 多模型的關聯與響應式 UI 連動。
* **Swift 6 並行安全 (Strict Concurrency)**
  * 全面適配 Swift 6，透過 `@MainActor` 與 `Sendable` 協議確保跨執行緒 (Thread Boundary) 的資料傳遞安全，達成 Zero Data Race。

---

## 系統架構 (Architecture)

本專案採用嚴謹的 **MVVM (Model-View-ViewModel)** 設計模式與**策略模式 (Strategy Pattern)**，確保高度的可測試性與模組解耦。

```text
TriAssistOS/
├── Models/              # SwiftData 資料模型 (Expense, Event, TodoTask)
├── Services/            # AI 服務層
│   ├── AIServiceProtocol.swift        # 定義統一的 AI 介面
│   ├── CloudAIService.swift           # Gemini API 實作
│   └── AppleIntelligenceService.swift # 地端神經網路實作
├── ViewModels/          # 業務邏輯大腦 
│   └── DashboardViewModel.swift 
└── Views/               # 五大核心 UI 模組
    ├── DashboardView.swift  # 智慧管家主控台
    ├── CalendarView.swift   # 整月行事曆視圖
    ├── TodoListView.swift   # 待辦清單與狀態追蹤
    ├── FinanceView.swift    # 財務流水帳視圖
    └── SettingsView.swift   # 系統設定與 API Key 管理
```

安裝與執行 (Installation)
1. 環境要求: • Xcode 15.0 或以上版本。 • iOS 17.0 或以上版本 (實機測試建議 iOS 18 以獲得完整的 UI 支援)。
3. API Key 設定: • 第一次開啟 App 時，請導覽至「系統設定」分頁。 • 若選擇「雲端高效能 AI」，請輸入您的 Google Gemini API Key。 • 若選擇「Apple Intelligence」，請確保設備支援並已於系統層級開啟。
開發團隊 (Team)
國立臺北科技大學 (NTUT) 資訊工程系
111590022 資工四 丁勇智
授權條款 (License)
This project is licensed under the MIT License - see the LICENSE file for details.
