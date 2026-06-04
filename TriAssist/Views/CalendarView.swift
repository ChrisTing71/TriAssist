//
//  CalendarView.swift
//  TriAssist
//
//  Created by 丁帥 on 2026/6/4.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    
    // 1. 抓取所有行程並按時間排序
    @Query(sort: \Event.startTime) private var allEvents: [Event]
    
    // 2. 狀態管理：儲存使用者在月曆上點選的日期（預設為今天）
    @State private var selectedDate = Date()
    @State private var isShowingAddSheet = false
    
    // 3. 計算屬性：篩選出與選定日期相同（同（年-月-日））的行程
    private var filteredEvents: [Event] {
        allEvents.filter { event in
            Calendar.current.isDate(event.startTime, inSameDayAs: selectedDate)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // 區塊一：Apple Calendar 風格的頂部整月圖形選擇器
                DatePicker(
                    "選擇日期",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical) // 🌟 關鍵：展現出整個月分面板
                .padding(.horizontal)
                .background(Color(.systemBackground))
                
                Divider()
                
                // 區塊二：下方顯示該日期的行程列表
                List {
                    Section(header: Text("\(selectedDate.formatted(date: .abbreviated, time: .omitted)) 行程")) {
                        if filteredEvents.isEmpty {
                            // 當天沒行程時的優雅降級顯示
                            Text("今天沒有安排行程")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .listRowAlignmentCenter() // 自訂置中樣式
                        } else {
                            ForEach(filteredEvents) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title)
                                        .font(.headline)
                                    HStack {
                                        Image(systemName: "clock")
                                        Text("\(event.startTime.formatted(date: .omitted, time: .shortened)) - \(event.endTime.formatted(date: .omitted, time: .shortened))")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            }
                            .onDelete(perform: deleteEvents)
                        }
                    }
                }
                .listStyle(.plain) // 讓風格更貼近 Apple 原生行事曆的俐落感
            }
            .navigationTitle("行事曆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { isShowingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            // 點擊 + 號手動新增，並自動將目前的選擇日期帶入當作預設值
            .sheet(isPresented: $isShowingAddSheet) {
                AddEventView(defaultDate: selectedDate)
            }
        }
    }
    
    private func deleteEvents(at offsets: IndexSet) {
        // 必須對照篩選後的陣列找到 SwiftData 真正的實例進行刪除
        for index in offsets {
            let eventToDelete = filteredEvents[index]
            modelContext.delete(eventToDelete)
        }
    }
}

// 擴充一個方便清單提示文字置中的 ViewModifier
extension View {
    func listRowAlignmentCenter() -> some View {
        HStack {
            Spacer()
            self
            Spacer()
        }
    }
}

// MARK: - 手動新增行程表單（優化版）
struct AddEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // 接收外部帶入的點選日期，讓使用者在 6/10 點新增時，預設時間就是 6/10
    var defaultDate: Date
    
    @State private var title = ""
    @State private var start = Date()
    @State private var end = Date()
    
    // 在初始化時根據點選日期校準表單時間
    init(defaultDate: Date) {
        self.defaultDate = defaultDate
        _start = State(initialValue: defaultDate)
        // 預設一小時後結束
        _end = State(initialValue: defaultDate.addingTimeInterval(3600))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("行程資訊")) {
                    TextField("行程名稱", text: $title)
                }
                
                Section(header: Text("時間設定")) {
                    DatePicker("開始時間", selection: $start)
                        .onChange(of: start) { _, newStart in
                            // 自動防呆：開始時間往後調時，結束時間連動往後推一小時
                            if end < newStart {
                                end = newStart.addingTimeInterval(3600)
                            }
                        }
                    DatePicker("結束時間", selection: $end, in: start...)
                }
            }
            .navigationTitle("新增行程")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        let newEvent = Event(title: title, startTime: start, endTime: end)
                        modelContext.insert(newEvent)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: [Expense.self, Event.self, TodoTask.self], inMemory: true)
}
