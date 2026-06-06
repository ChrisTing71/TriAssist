//
//  FinanceView.swift
//  TriAssist
//

import SwiftUI
import SwiftData

// MARK: - Category helpers
private func categoryColor(_ category: String) -> Color {
    switch category {
    case "飲食", "餐飲", "食物", "午餐", "晚餐", "早餐", "咖啡": return .orange
    case "娛樂", "遊戲", "電影", "休閒": return .purple
    case "交通", "計程車", "捷運", "公車": return Color(.systemYellow)
    case "購物": return .blue
    case "住宿", "房租": return .green
    default: return Color(.systemGray)
    }
}

private func categoryIcon(_ category: String) -> String {
    switch category {
    case "飲食", "餐飲", "食物", "午餐", "晚餐", "早餐", "咖啡": return "fork.knife"
    case "娛樂", "遊戲", "電影", "休閒": return "film.fill"
    case "交通", "計程車", "捷運", "公車": return "car.fill"
    case "購物": return "bag.fill"
    case "住宿", "房租": return "house.fill"
    default: return "creditcard.fill"
    }
}

// MARK: - FinanceView
struct FinanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    @State private var selectedTab = 0

    private var totalAmount: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    private var categoryTotals: [(category: String, total: Double)] {
        let grouped = Dictionary(grouping: expenses, by: \.category)
        return grouped
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            Group {
                if expenses.isEmpty {
                    ContentUnavailableView(
                        "尚無消費紀錄",
                        systemImage: "creditcard.and.123",
                        description: Text("對智慧管家說：「午餐吃了 150 元」即可記帳。")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            statsCard
                            segmentedTabs
                            if selectedTab == 0 {
                                expenseList
                            } else {
                                categoryBreakdown
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Finance")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "dollarsign.circle")
                        .foregroundColor(.blue)
                }
            }
        }
    }

    // MARK: Stats Card
    private var statsCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("金額洞察")
                        .font(.headline)
                        .bold()
                    Text("本月消費概覽")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("- $\(Int(totalAmount))")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.red)
                    Text("\(expenses.count) 筆紀錄")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Proportional color bar
            if totalAmount > 0 {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(categoryTotals, id: \.category) { item in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(categoryColor(item.category))
                                .frame(width: max(4, geo.size.width * CGFloat(item.total / totalAmount)))
                        }
                    }
                }
                .frame(height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 5))

                // Legend
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(categoryTotals.prefix(6), id: \.category) { item in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(categoryColor(item.category))
                                    .frame(width: 8, height: 8)
                                Text(item.category)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: Segmented Tabs
    private var segmentedTabs: some View {
        Picker("", selection: $selectedTab) {
            Text("統計").tag(0)
            Text("資訊").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
    }

    // MARK: Expense List
    private var expenseList: some View {
        LazyVStack(spacing: 10) {
            ForEach(expenses) { expense in
                expenseRow(expense)
            }
        }
        .padding(.horizontal, 16)
    }

    private func expenseRow(_ expense: Expense) -> some View {
        HStack(spacing: 14) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(categoryColor(expense.category).opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: categoryIcon(expense.category))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(categoryColor(expense.category))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.item)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(expense.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("- $\(Int(expense.amount))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    // MARK: Category Breakdown
    private var categoryBreakdown: some View {
        LazyVStack(spacing: 10) {
            ForEach(categoryTotals, id: \.category) { item in
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(categoryColor(item.category).opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: categoryIcon(item.category))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(categoryColor(item.category))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.category)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("\(expenses.filter { $0.category == item.category }.count) 筆")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("- $\(Int(item.total))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(14)
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    FinanceView()
        .modelContainer(for: [Expense.self, Event.self, TodoTask.self], inMemory: true)
}
