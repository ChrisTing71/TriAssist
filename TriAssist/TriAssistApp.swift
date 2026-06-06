//
//  TriAssistApp.swift
//  TriAssist
//

import SwiftUI
import SwiftData

@main
struct TriAssistApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "square.grid.2x2.fill") }

                CalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }

                TodoListView()
                    .tabItem { Label("Todo", systemImage: "checklist") }

                FinanceView()
                    .tabItem { Label("Finance", systemImage: "wallet.bifold.fill") }

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            .modelContainer(for: [Expense.self, Event.self, TodoTask.self])
        }
    }
}
