# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TriAssist is a SwiftUI iOS app (iOS 17+, Swift 6) built as a personal life assistant. It accepts natural language input and uses AI to automatically classify entries into calendar events, todo tasks, or shopping items. It also provides a daily AI briefing, a location-aware Task Radar, and recurring routine management.

## Build & Run

Open `TriAssist.xcodeproj` in Xcode and run on a simulator or device. No package manager (no SPM, no CocoaPods).

```bash
# Build from command line (simulator)
xcodebuild -project TriAssist.xcodeproj -scheme TriAssist -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run unit tests
xcodebuild test -project TriAssist.xcodeproj -scheme TriAssist -destination 'platform=iOS Simulator,name=iPhone 16'
```

Apple Intelligence features require a physical device running iOS 18+ with Apple Intelligence enabled — `FoundationModels` is not supported on the simulator.

## Tab Structure (5 tabs)

| Tab | View | Description |
|-----|------|-------------|
| Dashboard | `DashboardView` | Natural language input + AI daily briefing timeline |
| Calendar | `CalendarView` | Graphical date picker + per-day event list |
| Todo | `TodoListView` | Todo tasks + shopping list |
| Task Radar | `MapRadarView` | GPS-based nearby store scanner |
| Settings | `SettingsView` | Auth, AI engine, API key, recurring routines |

## Architecture

**MVVM + Strategy Pattern**

- `Models/DataModels.swift` — three SwiftData models: `Event`, `TodoTask`, `ShoppingItem`. The shared `modelContainer` is registered once in `TriAssistApp.swift` and injected via `@Environment(\.modelContext)`.
- `Models/RoutineModels.swift` — `RecurringEvent` struct (Codable) representing weekly fixed schedules stored in `UserDefaults` via `RoutineManager`.
- `Models/AppTips.swift` — five `TipKit` tip structs, one per major UI affordance.
- `Models/AuthModels.swift` — `AuthUser` and `AuthProvider` (Apple / Google).
- `Services/AIServiceProtocol.swift` — `AIServiceProtocol` with two methods: `parseUserIntent` → `AIResultStructured` and `generateDailyPlan` → `[DailyScheduleItem]`. `AIResultStructured` is `@Generable` for Apple Intelligence and decoded with `JSONDecoder` for Gemini.
- `Services/CloudAIService.swift` — calls Gemini 2.5 Flash REST API (`responseMimeType: application/json`).
- `Services/AppleIntelligenceService.swift` — uses `LanguageModelSession` from `FoundationModels` for on-device inference.
- `Services/RoutineManager.swift` — `@Observable` service that persists `[RecurringEvent]` to `UserDefaults` and exposes `aiSummary: String` for injection into the daily briefing prompt.
- `Services/AuthManager.swift` — `@Observable` service handling Sign in with Apple and Sign in with Google flows.
- `ViewModels/DashboardViewModel.swift` — `@MainActor @Observable`. Owns AI engine selection, text input state, daily briefing loading, and result banner auto-dismiss. Persists `selectedAIEngine` and `customApiKey` to `UserDefaults`.
- `ViewModels/MapRadarViewModel.swift` — `@MainActor @Observable`. Manages `CLLocationManager`, `MKLocalSearch`, POI annotation list, and per-POI AI description generation.
- `Views/` — five tab views. Only `DashboardView` and `MapRadarView` have dedicated ViewModels; `CalendarView` and `TodoListView` query SwiftData directly via `@Query`. `SettingsView` uses `@AppStorage` mirroring the same `UserDefaults` keys as `DashboardViewModel`.

## Key Design Details

**AI engine selection:** `DashboardViewModel.aiService` is a computed property returning either `CloudAIService()` or `AppleIntelligenceService()` based on `selectedEngine`. The same keys (`"selectedAIEngine"`, `"customApiKey"`) are shared between `SettingsView` (`@AppStorage`) and `DashboardViewModel` (`UserDefaults`).

**Swift 6 concurrency:** All UI and SwiftData mutations happen on `@MainActor`. Data passed into `async` AI calls is converted to plain `String` (Sendable) before crossing the actor boundary in `DashboardViewModel.loadDailyBriefing`.

**Structured AI output:** `AIResultStructured` uses `@Generable` + `@Guide` for Apple Intelligence and `JSONDecoder` for Gemini. `@Guide` annotations on boolean fields prevent false positives. Double-validation (e.g. `result.hasEvent && !result.eventTitle.isEmpty`) guards against hallucination before SwiftData inserts.

**Daily briefing:** Loaded once automatically via `.task` on `DashboardView` appear, guarded by `hasLoadedBriefing` and a data hash. Force-refresh passes `forceRefresh: true`. Routine summary from `RoutineManager.aiSummary` is injected into the prompt so the AI can avoid fixed time slots.

**Task Radar:** `MapRadarViewModel.scanNearby` builds a keyword query list from active todos and shopping items, runs `MKLocalSearch` within 500 m, then calls Gemini to write a short Chinese recommendation sentence per POI. `matchedItems(for:)` applies strict keyword matching to determine which todos/shopping items can be completed at each store.

**TipKit:** Tips are defined in `AppTips.swift` and configured once in `TriAssistApp.swift` via `Tips.configure()`. Each tip appears as a `popoverTip` or `TipView` inline in its relevant view and is invalidated with `.actionPerformed` after the user interacts.

**Authentication:** `AuthManager` handles Apple and Google sign-in. User data (display name, email, provider) is stored in `UserDefaults`; data models remain local (SwiftData) regardless of login state.
