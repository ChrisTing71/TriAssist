//
//  CalendarView.swift
//  TriAssist
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.startTime) private var allEvents: [Event]

    @State private var selectedDate = Date()
    @State private var isShowingAddSheet = false

    private var filteredEvents: [Event] {
        allEvents.filter { Calendar.current.isDate($0.startTime, inSameDayAs: selectedDate) }
    }

    private var upcomingEvents: [Event] {
        let today = Calendar.current.startOfDay(for: Date())
        return allEvents.filter { $0.startTime >= today }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Calendar grid
                    DatePicker("選擇日期", selection: $selectedDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .padding(.horizontal, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Events for selected date
                    VStack(alignment: .leading, spacing: 10) {
                        if filteredEvents.isEmpty {
                            HStack {
                                Image(systemName: "calendar.badge.checkmark")
                                    .foregroundColor(.secondary)
                                Text("今天沒有安排行程")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            ForEach(filteredEvents) { event in
                                eventRow(event)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Image(systemName: "barcode.viewfinder")
                            .foregroundColor(.blue)
                        Button {
                            isShowingAddSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddEventView(defaultDate: selectedDate)
            }
        }
    }

    private func eventRow(_ event: Event) -> some View {
        HStack(spacing: 14) {
            // Date number column
            VStack(spacing: 2) {
                Text(event.startTime.formatted(.dateTime.day()))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .frame(width: 36)

            // Colored accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(eventColor(event))
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text("- \(event.title)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                HStack(spacing: 5) {
                    Circle()
                        .fill(eventColor(event))
                        .frame(width: 7, height: 7)
                    Text("\(event.startTime.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteEvent(event)
            } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }

    private func eventColor(_ event: Event) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .teal]
        let index = abs(event.title.hashValue) % colors.count
        return colors[index]
    }

    private func deleteEvent(_ event: Event) {
        modelContext.delete(event)
    }
}

extension View {
    func listRowAlignmentCenter() -> some View {
        HStack {
            Spacer()
            self
            Spacer()
        }
    }
}

// MARK: - Add Event Sheet
struct AddEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var defaultDate: Date
    @State private var title = ""
    @State private var start = Date()
    @State private var end = Date()

    init(defaultDate: Date) {
        self.defaultDate = defaultDate
        _start = State(initialValue: defaultDate)
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
