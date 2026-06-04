//
//  ScheduleView.swift
//  TriAssist
//
//  Created by 丁帥 on 2026/6/4.
//

import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Event.startTime) private var events: [Event]
    @Query private var todos: [TodoTask]
    
    var body: some View {
        NavigationStack {
            Group {
                // 依據簡報第 94, 95 頁，若完全沒有行程或待辦，顯示無資料提示畫面
                if events.isEmpty && todos.isEmpty {
                    ContentUnavailableView(
                        "尚無任何行程與待辦",
                        systemImage: "calendar.badge.plus",
                        description: Text("快去主畫面吩咐 AI 幫您安排日程吧！")
                    )
                } else {
                    List {
                        // 行事曆行程區區塊
                        if !events.isEmpty {
                            Section(header: Text("今日行事曆")) {
                                ForEach(events) { event in
                                    VStack(alignment: .leading) {
                                        Text(event.title)
                                            .font(.headline)
                                        Text("\(event.startTime.formatted(date: .omitted, time: .shortened)) - \(event.endTime.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .onDelete(perform: deleteEvents) // 整合簡報第 85 頁滑動刪除
                            }
                        }
                        
                        // 待辦事項區區塊
                        if !todos.isEmpty {
                            Section(header: Text("待辦任務清單")) {
                                ForEach(todos) { todo in
                                    HStack {
                                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(todo.isCompleted ? .green : .gray)
                                            .onTapGesture {
                                                todo.isCompleted.toggle() // 點擊直接變更狀態
                                            }
                                        Text(todo.title)
                                            .strikethrough(todo.isCompleted)
                                            .foregroundColor(todo.isCompleted ? .gray : .primary)
                                    }
                                }
                                .onDelete(perform: deleteTodos)
                            }
                        }
                    }
                }
            }
            .navigationTitle("日程管家")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton() // 簡報第 85 頁：快速進入刪除排序模式
                }
            }
        }
    }
    
    // 實作簡報第 85 頁的 onDelete 刪除函式
    private func deleteEvents(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(events[index]) 
        }
    }
    
    private func deleteTodos(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(todos[index])
        }
    }
}

#Preview {
    ScheduleView()
        .modelContainer(for: [Expense.self, Event.self, TodoTask.self], inMemory: true)
}
