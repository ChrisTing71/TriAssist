# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TriAssist is a SwiftUI iOS app (iOS 17+, Swift 6) that uses natural language input to automatically categorize entries into expenses, calendar events, or todo tasks. It supports two AI backends via a strategy pattern.

## Build & Run

Open `TriAssist.xcodeproj` in Xcode and run on a simulator or device. There is no package manager (no SPM, no CocoaPods).

```bash
# Build from command line (simulator)
xcodebuild -project TriAssist.xcodeproj -scheme TriAssist -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run unit tests
xcodebuild test -project TriAssist.xcodeproj -scheme TriAssist -destination 'platform=iOS Simulator,name=iPhone 16'
```

For Apple Intelligence features to work, a physical device running iOS 18+ with Apple Intelligence enabled is required — simulator does not support `FoundationModels`.

## Architecture

**MVVM + Strategy Pattern**

- `Models/DataModels.swift` — three SwiftData models: `Expense`, `Event`, `TodoTask`. The shared `modelContainer` is registered once at the app root in `TriAssistApp.swift` and injected via `@Environment(\.modelContext)`.
- `Services/AIServiceProtocol.swift` — defines `AIServiceProtocol` with two methods: `parseUserIntent` (returns typed `AIResultStructured`) and `generateDailyPlan` (returns plain text). `AIResultStructured` is decorated with `@Generable` and `@Guide` for Apple's `FoundationModels` structured output.
- `Services/CloudAIService.swift` — calls Gemini 2.5 Flash REST API with `responseMimeType: application/json` to get structured output, then decodes into `AIResultStructured`.
- `Services/AppleIntelligenceService.swift` — uses `LanguageModelSession` from `FoundationModels` to run inference on-device. The session holds a persistent system prompt; time context is injected per-call into the user message.
- `ViewModels/DashboardViewModel.swift` — the single ViewModel for the whole app. Marked `@MainActor @Observable`. Selects the active `AIServiceProtocol` implementation based on `selectedEngine`. Persists `selectedAIEngine` and `customApiKey` to `UserDefaults`. The `hasLoadedBriefing` flag prevents re-fetching the daily plan on every tab switch.
- `Views/` — five tab views. Only `DashboardView` has a ViewModel; other views (`CalendarView`, `TodoListView`, `FinanceView`) query SwiftData directly via `@Query`. `SettingsView` uses `@AppStorage` mirroring the same `UserDefaults` keys as the ViewModel.

## Key Design Details

**AI engine selection:** `DashboardViewModel.aiService` is a computed property that returns either `CloudAIService()` or `AppleIntelligenceService()` based on `selectedEngine`. Settings are shared between `SettingsView` (`@AppStorage`) and the ViewModel (`UserDefaults`) using the same keys (`"selectedAIEngine"`, `"customApiKey"`).

**Swift 6 concurrency:** All UI and SwiftData mutations happen on `@MainActor`. Data passed into `async` AI calls is converted to plain `String` (Sendable) before crossing the actor boundary in `DashboardViewModel.loadDailyBriefing`.

**Structured AI output:** `AIResultStructured` uses `@Generable` for Apple Intelligence and is decoded with `JSONDecoder` for Gemini. The `@Guide` annotations on boolean fields are the primary mechanism for preventing false positives (e.g. marking something as an expense when no amount was mentioned). Double-validation (e.g. `result.hasExpense && result.expenseAmount > 0`) guards against AI hallucination before inserting into SwiftData.

**Daily briefing:** Called once automatically via `.task` on `DashboardView` appear, guarded by `hasLoadedBriefing`. Force-refresh (user taps the reload button) passes `forceRefresh: true` to bypass the guard. The button is disabled while `aiSuggestion` contains "正在" to prevent API spam.
