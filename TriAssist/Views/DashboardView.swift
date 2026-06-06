//
//  DashboardView.swift
//  TriAssist
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(RoutineManager.self) private var routineManager
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        inputSection
                        briefingCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }

                if !viewModel.lastActionResult.isEmpty {
                    resultBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 12)
                }
            }
            .animation(.spring(response: 0.3), value: viewModel.lastActionResult)
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Image(systemName: "barcode.viewfinder").foregroundColor(.blue)
                        Image(systemName: "dollarsign.circle").foregroundColor(.blue)
                    }
                }
            }
            .task {
                viewModel.routineSummary = routineManager.aiSummary
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
                Task { await viewModel.handleUserVoiceOrTextInput(modelContext: modelContext) }
            } label: {
                Group {
                    if viewModel.isProcessing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: viewModel.inputText.isEmpty ? "mic.fill" : "paperplane.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
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
                        viewModel.routineSummary = routineManager.aiSummary
                        await viewModel.loadDailyBriefing(modelContext: modelContext, forceRefresh: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(viewModel.isLoadingBriefing ? 360 : 0))
                        .animation(
                            viewModel.isLoadingBriefing
                                ? .linear(duration: 1).repeatForever(autoreverses: false)
                                : .default,
                            value: viewModel.isLoadingBriefing
                        )
                }
                .disabled(viewModel.isLoadingBriefing)
            }

            Text("AI 根據您的行程與待辦，優化今日時間分配。")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            if viewModel.isLoadingBriefing {
                loadingView
            } else if !viewModel.briefingMessage.isEmpty {
                emptyStateView(message: viewModel.briefingMessage)
            } else if viewModel.scheduleItems.isEmpty {
                emptyStateView(message: "今天目前沒有行程與待辦任務，跟我說說你今天的計畫吧！")
            } else {
                timelineView
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Timeline
    private var timelineView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.scheduleItems.enumerated()), id: \.element.id) { index, item in
                timelineRow(item, isLast: index == viewModel.scheduleItems.count - 1)
            }
        }
    }

    private func timelineRow(_ item: DailyScheduleItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(item.time.isEmpty ? "—" : item.time)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .trailing)
                .padding(.top, 3)

            VStack(spacing: 0) {
                Circle()
                    .fill(itemColor(item.type))
                    .frame(width: 9, height: 9)
                    .padding(.top, 5)
                if !isLast {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                        .padding(.bottom, -4)
                }
            }
            .frame(width: 24)
            .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: itemIcon(item.type))
                        .font(.caption)
                        .foregroundColor(itemColor(item.type))
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 2)
            .padding(.bottom, isLast ? 0 : 16)

            Spacer()
        }
    }

    // MARK: - States
    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView().tint(.blue)
            Text("AI 正在優化今日排程...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 36))
                .foregroundStyle(.blue.gradient)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Result Banner
    private var resultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            Text(viewModel.lastActionResult)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    // MARK: - Helpers
    private func itemColor(_ type: String) -> Color {
        switch type {
        case "event": return .blue
        case "todo": return .green
        default: return .orange
        }
    }

    private func itemIcon(_ type: String) -> String {
        switch type {
        case "event": return "calendar"
        case "todo": return "checkmark.circle"
        default: return "lightbulb.fill"
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Expense.self, Event.self, TodoTask.self], inMemory: true)
}
