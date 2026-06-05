# TriAssist - 智慧生活管家

![iOS](https://img.shields.io/badge/iOS-17.0+-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square&logo=swift)
![Architecture](https://img.shields.io/badge/Architecture-MVVM-blue?style=flat-square)
![Database](https://img.shields.io/badge/Database-SwiftData-red?style=flat-square)

TriAssist 是一款結合人工智慧的全方位生活管理 iOS 應用程式。透過自然語言輸入，一句話即可自動完成記帳、行程安排與待辦事項的歸檔，並具備每日排程優化建議。

---

## 核心特色

### 雙 AI 引擎策略分流
| 引擎 | 技術 | 特點 |
|---|---|---|
| 雲端高效能 AI | Google Gemini 2.5 Flash | 高準確度、支援複雜語意 |
| Apple Intelligence（地端） | FoundationModels | 完全離線、隱私保護 |

兩個引擎共用相同的 `AIServiceProtocol`，可在設定頁即時切換，無需重啟。

### 智慧語意解析
支援複合情境輸入，例如「明天下午三點要跟朋友喝咖啡花了 150 元」，系統會同時解析出：
- **行程**：明天 15:00 喝咖啡
- **記帳**：咖啡 150 元

搭配 few-shot prompt 設計與雙重防呆機制（`hasExpense && expenseAmount > 0`），確保資料不因 AI 幻覺而被誤寫入。

### 主動式每日排程建議
每日首次開啟自動讀取當日行程與未完成待辦，透過 AI 生成具體的時間軸排程建議。具備防刷機制（`hasLoadedBriefing` flag）與手動強制重載按鈕。

---

## 系統架構

採用 **MVVM + 策略模式（Strategy Pattern）**，AI 引擎實作細節對 ViewModel 完全透明。

```
TriAssist/
├── Models/
│   └── DataModels.swift              # SwiftData 模型：Expense, Event, TodoTask
├── Services/
│   ├── AIServiceProtocol.swift       # 統一 AI 介面 + @Generable 結構定義
│   ├── CloudAIService.swift          # Gemini 2.5 Flash REST API 實作
│   └── AppleIntelligenceService.swift# FoundationModels 地端推理實作
├── ViewModels/
│   └── DashboardViewModel.swift      # 全域業務邏輯（@MainActor @Observable）
└── Views/
    ├── DashboardView.swift           # 主控台：AI 輸入 + 每日建議看板
    ├── CalendarView.swift            # 月曆視圖
    ├── TodoListView.swift            # 待辦清單與狀態追蹤
    ├── FinanceView.swift             # 財務流水帳
    └── SettingsView.swift            # AI 引擎切換 + API Key 管理
```

`modelContainer` 在 `TriAssistApp.swift` 統一初始化，透過 `@Environment(\.modelContext)` 向下注入各 View。設定值（引擎選擇、API Key）透過 `UserDefaults` / `@AppStorage` 持久化。

---

## 安裝與執行

### 環境需求
- Xcode 15.0+
- iOS 17.0+（建議 iOS 18 以獲得完整 UI 支援）
- Apple Intelligence 功能需 iOS 18.1+ 實機並於系統設定中開啟

### 步驟
1. Clone 專案並以 Xcode 開啟 `TriAssist.xcodeproj`
2. 選擇目標裝置或模擬器，按下 Run（⌘R）
3. 首次啟動後前往「系統設定」分頁：
   - 若選擇**雲端高效能 AI**，輸入 [Google Gemini API Key](https://aistudio.google.com/app/apikey)
   - 若選擇 **Apple Intelligence**，確認設備已於系統層級開啟此功能

---

## 開發團隊

國立臺北科技大學 資訊工程系

| 學號 | 姓名 |
|---|---|
| 111590022 | 丁勇智 |
| 110590057 | 蔡昀祐 |

---

## 授權

[MIT License](LICENSE)
