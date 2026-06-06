//
//  TodoListView.swift
//  TriAssist
//

import SwiftUI
import SwiftData

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoTask.dueDate) private var todos: [TodoTask]

    @State private var isShowingAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if todos.isEmpty {
                    ContentUnavailableView(
                        "清單空空如也",
                        systemImage: "checklist",
                        description: Text("點擊 + 建立新任務，讓生活更有條理")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(todos) { todo in
                                todoRow(todo)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Todo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddTodoView()
            }
        }
    }

    private func todoRow(_ todo: TodoTask) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Rounded-square checkbox
            Button {
                todo.isCompleted.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(todo.isCompleted ? Color.green : Color.secondary.opacity(0.5), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    if todo.isCompleted {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text(todo.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(todo.isCompleted ? .secondary : .primary)
                    .strikethrough(todo.isCompleted, color: .secondary)

                if let date = todo.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(todo)
            } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Todo Sheet
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
