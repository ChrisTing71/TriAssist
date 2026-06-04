//
//  TodoListView.swift
//  TriAssist
//
//  Created by 丁帥 on 2026/6/4.
//

import SwiftUI
import SwiftData

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoTask.dueDate) private var todos: [TodoTask]
    
    @State private var isShowingAddSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                if todos.isEmpty {
                    ContentUnavailableView("清單空空如也", systemImage: "checklist", description: Text("點擊 + 建立新任務，讓生活更有條理"))
                } else {
                    ForEach(todos) { todo in
                        HStack {
                            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(todo.isCompleted ? .green : .gray)
                                .onTapGesture {
                                    todo.isCompleted.toggle()
                                }
                            
                            VStack(alignment: .leading) {
                                Text(todo.title)
                                    .strikethrough(todo.isCompleted)
                                if let date = todo.dueDate {
                                    Text("截止日: \(date.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteTodos)
                }
            }
            .navigationTitle("待辦清單")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { isShowingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddTodoView()
            }
        }
    }
    
    private func deleteTodos(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(todos[index])
        }
    }
}

// 手動新增待辦的表單
struct AddTodoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var includeDate = false
    @State private var dueDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("任務內容", text: $title)
                Toggle("設定截止日期", isOn: $includeDate)
                if includeDate {
                    DatePicker("截止日期", selection: $dueDate, displayedComponents: .date)
                }
            }
            .navigationTitle("新待辦任務")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("建立") {
                        let newTask = TodoTask(title: title, isCompleted: false, dueDate: includeDate ? dueDate : nil)
                        modelContext.insert(newTask)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

#Preview {
    TodoListView()
        .modelContainer(for: [Expense.self, Event.self, TodoTask.self], inMemory: true)
}
