//
//  TriAssistApp.swift
//  TriAssist
//

import SwiftUI
import SwiftData

@main
struct TriAssistApp: App {
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoggedIn {
                    mainTabView
                        .transition(.opacity)
                } else {
                    LoginView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isLoggedIn)
            .environment(authManager)
        }
        .modelContainer(for: [Expense.self, Event.self, TodoTask.self])
    }

    private var mainTabView: some View {
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
    }
}
