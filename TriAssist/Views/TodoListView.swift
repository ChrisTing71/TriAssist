//
//  TodoListView.swift
//  TriAssist
//

import SwiftUI
import SwiftData

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoTask.dueDate) private var todos: [TodoTask]
    @Query(sort: \ShoppingItem.name) private var shoppingItems: [ShoppingItem]

    private var sortedShoppingItems: [ShoppingItem] {
        shoppingItems.sorted { a, b in
            if a.isChecked != b.isChecked { return !a.isChecked }
            return a.name < b.name
        }
    }

    @State private var isShowingAddTodoSheet = false
    @State private var isShowingAddShoppingSheet = false
    @State private var editingTodo: TodoTask? = nil
    @State private var editingShoppingItem: ShoppingItem? = nil

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Todo Section
                Section {
                    if todos.isEmpty {
                        Text("暫無待辦任務")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 10)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(todos) { todo in
                            todoRow(todo)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        }
                    }
                } header: {
                    sectionHeader("待辦清單", icon: "checklist", action: { isShowingAddTodoSheet = true })
                }

                // MARK: - Shopping Section
                Section {
                    if shoppingItems.isEmpty {
                        Text("暫無購物項目")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 10)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(sortedShoppingItems) { item in
                            shoppingRow(item)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        }
                    }
                } header: {
                    sectionHeader("購物清單", icon: "cart", action: { isShowingAddShoppingSheet = true })
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationTitle("Todo")
            .sheet(isPresented: $isShowingAddTodoSheet) { AddTodoView() }
            .sheet(isPresented: $isShowingAddShoppingSheet) { AddShoppingItemView() }
            .sheet(item: $editingTodo) { EditTodoView(todo: $0) }
            .sheet(item: $editingShoppingItem) { EditShoppingItemView(item: $0) }
        }
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.primary)
                .textCase(nil)
            Spacer()
            Button(action: action) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Todo Row
    private func todoRow(_ todo: TodoTask) -> some View {
        HStack(alignment: .top, spacing: 14) {
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
                    .foregroundColor(isOverdue(date, completed: todo.isCompleted) ? .red : .secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
        .swipeActions(edge: .leading) {
            Button { editingTodo = todo } label: {
                Label("編輯", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(todo)
            } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }

    // MARK: - Shopping Row
    private func shoppingRow(_ item: ShoppingItem) -> some View {
        HStack(spacing: 14) {
            Button {
                item.isChecked.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(item.isChecked ? Color.blue : Color.secondary.opacity(0.5), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    if item.isChecked {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(item.isChecked ? .secondary : .primary)
                    .strikethrough(item.isChecked, color: .secondary)
                if !item.quantity.isEmpty {
                    Text(item.quantity)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "cart")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
        .swipeActions(edge: .leading) {
            Button { editingShoppingItem = item } label: {
                Label("編輯", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(item)
            } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }

    private func isOverdue(_ date: Date, completed: Bool) -> Bool {
        !completed && date < Calendar.current.startOfDay(for: Date())
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
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("建立") {
                        modelContext.insert(TodoTask(title: title, isCompleted: false, dueDate: includeDate ? dueDate : nil))
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Todo Sheet
struct EditTodoView: View {
    @Environment(\.dismiss) private var dismiss

    let todo: TodoTask
    @State private var title: String
    @State private var includeDate: Bool
    @State private var dueDate: Date

    init(todo: TodoTask) {
        self.todo = todo
        _title = State(initialValue: todo.title)
        _includeDate = State(initialValue: todo.dueDate != nil)
        _dueDate = State(initialValue: todo.dueDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("任務內容", text: $title)
                Toggle("設定截止日期", isOn: $includeDate)
                if includeDate {
                    DatePicker("截止日期", selection: $dueDate, displayedComponents: .date)
                }
            }
            .navigationTitle("編輯任務")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        todo.title = title
                        todo.dueDate = includeDate ? dueDate : nil
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Shopping Item Sheet
struct AddShoppingItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var quantity = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("品項資訊")) {
                    TextField("名稱", text: $name)
                    TextField("數量（選填，例：2 個、300g）", text: $quantity)
                }
            }
            .navigationTitle("新增購物項目")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("建立") {
                        modelContext.insert(ShoppingItem(name: name, quantity: quantity))
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Shopping Item Sheet
struct EditShoppingItemView: View {
    @Environment(\.dismiss) private var dismiss

    let item: ShoppingItem
    @State private var name: String
    @State private var quantity: String

    init(item: ShoppingItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _quantity = State(initialValue: item.quantity)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("品項資訊")) {
                    TextField("名稱", text: $name)
                    TextField("數量（選填）", text: $quantity)
                }
            }
            .navigationTitle("編輯購物項目")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        item.name = name
                        item.quantity = quantity
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    TodoListView()
        .modelContainer(for: [Event.self, TodoTask.self, ShoppingItem.self], inMemory: true)
}
