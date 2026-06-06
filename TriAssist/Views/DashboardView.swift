//
//  DashboardView.swift
//  TriAssist
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()
    @State private var selectedFilter = 0

    private let filters = ["活動", "事務", "其他"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    inputSection
                    briefingCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Image(systemName: "barcode.viewfinder")
                            .foregroundColor(.blue)
                        Image(systemName: "dollarsign.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            .task {
                await viewModel.loadDailyBriefing(modelContext: modelContext)
            }
            .alert("AI 功能未啟用", isPresented: $viewModel.showAIUnavailableAlert) {
                Button("確定", role: .cancel) { }
            } message: {
                Text("您的裝置目前不支援 Apple Intelligence...")
            }
        }
    }

    // MARK: - Input Section
    private var inputSection: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("輸入文字指令...", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(14)
                .disabled(viewModel.isProcessing)

            Button {
                Task {
                    await viewModel.handleUserVoiceOrTextInput(modelContext: modelContext)
                }
            } label: {
                Image(systemName: viewModel.inputText.isEmpty ? "mic.fill" : "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .disabled(viewModel.isProcessing)
        }
    }

    // MARK: - Briefing Card
    private var briefingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("智慧每日排程建議")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    Task {
                        await viewModel.loadDailyBriefing(modelContext: modelContext, forceRefresh: true)
                    }
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .disabled(viewModel.aiSuggestion.contains("正在"))
            }

            Text("AI 才優化後，請您參考今日的排程建議。")
                .font(.caption)
                .foregroundColor(.secondary)

            // Filter chips
            HStack(spacing: 8) {
                ForEach(Array(filters.enumerated()), id: \.offset) { index, label in
                    Button(label) {
                        selectedFilter = index
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(selectedFilter == index ? Color.blue : Color(.tertiarySystemBackground))
                    .foregroundColor(selectedFilter == index ? .white : .primary)
                    .clipShape(Capsule())
                    .font(.subheadline)
                    .fontWeight(selectedFilter == index ? .semibold : .regular)
                }
            }

            Divider()

            if viewModel.isProcessing {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.blue)
                    Text("TriAssist 正在處理中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            } else if viewModel.aiSuggestion.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue.gradient)
                    Text("您好，我是 TriAssist")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                Text(viewModel.aiSuggestion)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Expense.self, Event.self, TodoTask.self], inMemory: true)
}
