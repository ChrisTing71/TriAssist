//
//  RoutineEditorView.swift
//  TriAssist
//

import SwiftUI

struct RoutineEditorView: View {
    @Environment(RoutineManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var m = manager

        NavigationStack {
            Form {
                // MARK: Daily fixed
                Section {
                    Toggle("起床時間", isOn: $m.hasWakeUp)
                    if m.hasWakeUp {
                        TimePicker(label: "起床", minutes: $m.wakeUpMinutes)
                    }
                    Toggle("睡眠時間", isOn: $m.hasSleep)
                    if m.hasSleep {
                        TimePicker(label: "睡眠", minutes: $m.sleepMinutes)
                    }
                } header: {
                    Label("每日固定", systemImage: "sun.and.horizon.fill")
                }

                // MARK: Weekly recurring
                Section {
                    ForEach($m.recurringEvents) { $event in
                        NavigationLink {
                            RecurringEventEditView(event: $event, onSave: { manager.save() })
                        } label: {
                            RecurringEventRow(event: event)
                        }
                    }
                    .onDelete { offsets in
                        m.recurringEvents.remove(atOffsets: offsets)
                        manager.save()
                    }

                    Button {
                        m.recurringEvents.append(
                            RecurringEvent(name: "新課程", weekdays: [0], startMinutes: 9 * 60, endMinutes: 10 * 60)
                        )
                    } label: {
                        Label("新增課程 / 班表", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Label("每週固定行程", systemImage: "calendar.badge.clock")
                } footer: {
                    Text("這些固定行程會自動提供給 AI，讓每日排程建議更準確。")
                }
            }
            .navigationTitle("固定行程設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") {
                        manager.save()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}

// MARK: - Row in the list
struct RecurringEventRow: View {
    let event: RecurringEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.name.isEmpty ? "（未命名）" : event.name)
                .font(.subheadline)
                .fontWeight(.semibold)
            HStack(spacing: 6) {
                Text("週\(event.weekdayDisplay)")
                    .font(.caption)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
                Text("\(event.startMinutes.timeString) – \(event.endMinutes.timeString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Edit detail view
struct RecurringEventEditView: View {
    @Binding var event: RecurringEvent
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    // Local dates to drive DatePicker (time-of-day only)
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()

    var body: some View {
        Form {
            Section("名稱") {
                TextField("課程 / 班表名稱", text: $event.name)
            }

            Section("上課日") {
                WeekdayPicker(selectedDays: $event.weekdays)
                    .padding(.vertical, 4)
            }

            Section("時間") {
                DatePicker("開始", selection: $startDate, displayedComponents: .hourAndMinute)
                    .onChange(of: startDate) { _, d in event.startMinutes = minutesFrom(d) }
                DatePicker("結束", selection: $endDate, displayedComponents: .hourAndMinute)
                    .onChange(of: endDate) { _, d in event.endMinutes = minutesFrom(d) }
            }
        }
        .navigationTitle("編輯行程")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("儲存") {
                    onSave()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            startDate = dateFrom(event.startMinutes)
            endDate   = dateFrom(event.endMinutes)
        }
    }

    private func dateFrom(_ minutes: Int) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = minutes / 60; c.minute = minutes % 60
        return Calendar.current.date(from: c) ?? Date()
    }

    private func minutesFrom(_ date: Date) -> Int {
        let c = Calendar.current
        return c.component(.hour, from: date) * 60 + c.component(.minute, from: date)
    }
}

// MARK: - Weekday toggle picker
struct WeekdayPicker: View {
    @Binding var selectedDays: [Int]
    private let labels = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { day in
                let selected = selectedDays.contains(day)
                Button {
                    if selected {
                        selectedDays.removeAll { $0 == day }
                    } else {
                        selectedDays.append(day)
                        selectedDays.sort()
                    }
                } label: {
                    Text(labels[day])
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(width: 34, height: 34)
                        .background(selected ? Color.blue : Color(.tertiarySystemBackground))
                        .foregroundColor(selected ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Reusable time picker row
struct TimePicker: View {
    let label: String
    @Binding var minutes: MinuteOfDay

    @State private var date: Date = Date()

    var body: some View {
        DatePicker(label, selection: $date, displayedComponents: .hourAndMinute)
            .onAppear {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                c.hour = minutes / 60; c.minute = minutes % 60
                date = Calendar.current.date(from: c) ?? Date()
            }
            .onChange(of: date) { _, d in
                let c = Calendar.current
                minutes = c.component(.hour, from: d) * 60 + c.component(.minute, from: d)
            }
    }
}

#Preview {
    RoutineEditorView()
        .environment(RoutineManager())
}
