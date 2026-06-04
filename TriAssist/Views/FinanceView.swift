//
//  FinanceView.swift
//  TriAssist
//
//  Created by 丁帥 on 2026/6/4.
//

import SwiftUI
import SwiftData

struct FinanceView: View {
    @Environment(\.modelContext) private var modelContext
    
    // 抓取所有記帳資料，並依據簡報第 38 頁語法，按時間由新到舊排序
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    
    var body: some View {
        NavigationStack {
            Group {
                if expenses.isEmpty {
                    ContentUnavailableView(
                        "尚無消費紀錄",
                        systemImage: "creditcard.and.123",
                        description: Text("對智慧管家說：『午餐吃了 150 元』即可記帳。")
                    )
                } else {
                    List {
                        // 總花費快速面板
                        Section {
                            HStack {
                                Text("本月總開銷")
                                    .bold()
                                Spacer()
                                Text("$ \(Int(expenses.reduce(0) { $0 + $1.amount }))")
                                    .font(.title3)
                                    .foregroundColor(.red)
                                    .bold()
                            }
                        }
                        
                        // 流水帳明細列表
                        Section(header: Text("消費明細")) {
                            ForEach(expenses) { expense in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(expense.item)
                                            .font(.headline)
                                        Text(expense.category)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    Spacer()
                                    Text("$ \(Int(expense.amount))")
                                        .font(.headline)
                                }
                            }
                            .onDelete(perform: deleteExpenses) // 滑動刪除
                        }
                    }
                }
            }
            .navigationTitle("財務管家")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func deleteExpenses(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(expenses[index])
        }
    }
}

#Preview {
    FinanceView()
        .modelContainer(for: [Expense.self, Event.self, TodoTask.self], inMemory: true)
}
