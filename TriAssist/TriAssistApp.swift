//
//  TriAssistApp.swift
//  TriAssist
//
//  Created by 丁帥 on 2026/6/4.
//

import SwiftUI
import SwiftData

@main
struct TriAssistApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView()
                    .tabItem { Label("智慧管家", systemImage: "brain.head.profile") }
                
                CalendarView()
                    .tabItem { Label("行事曆", systemImage: "calendar") }
                
                TodoListView()
                    .tabItem { Label("待辦清單", systemImage: "checklist") }
                
                FinanceView()
                    .tabItem { Label("財務管家", systemImage: "creditcard.fill") }
                
                SettingsView()
                    .tabItem { Label("系統設定", systemImage: "gearshape") }
            }
            .modelContainer(for: [Expense.self, Event.self, TodoTask.self])
        }
    }
}
