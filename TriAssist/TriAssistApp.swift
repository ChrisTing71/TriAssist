//
//  TriAssistApp.swift
//  TriAssist
//

import SwiftUI
import SwiftData
import TipKit

@main
struct TriAssistApp: App {
    @State private var authManager = AuthManager()
    @State private var routineManager = RoutineManager()

    init() {
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "square.grid.2x2.fill") }

                CalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }

                TodoListView()
                    .tabItem { Label("Todo", systemImage: "checklist") }

                MapRadarView()
                    .tabItem { Label("Task Radar", systemImage: "map.fill") }

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            .environment(authManager)
            .environment(routineManager)
        }
        .modelContainer(for: [Event.self, TodoTask.self, ShoppingItem.self])
    }
}
