//
//  DashboardView.swift
//  TriAssist
//
//  Created by 丁帥 on 2026/6/4.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                // 頂部 AI 今日日程優化建議看板
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.orange)
                        Text("TriAssist 今日排程建議")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer() // 🌟 將重試按鈕推至最右側
                        
                        // 🌟 新增：重新整理按鈕
                        Button(action: {
                            Task {
                                // 傳入 forceRefresh: true 強制要求 AI 重新生成
                                await viewModel.loadDailyBriefing(modelContext: modelContext, forceRefresh: true)
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.orange)
                                .padding(6)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Circle())
                        }
                        // 防呆機制：如果正在載入中，則暫時停用按鈕，防止連續點擊狂敲 API
                        .disabled(viewModel.aiSuggestion.contains("正在"))
                    }
                    
                    Text(viewModel.aiSuggestion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true) // 確保多行文字不被裁切
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .padding([.top, .horizontal])
                
                Spacer()
                
                // 核心對話狀態顯示區
                if viewModel.isProcessing {
                    ProgressView("TriAssist 正在處理中...")
                        .scaleEffect(1.2)
                        .tint(.blue)
                } else {
                    VStack(spacing: 15) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("您好，我是 TriAssist")
                            .font(.title3)
                            .bold()
                    }
                }
                
                Spacer()
                
                // 底部輸入區
                HStack(spacing: 12) {
                    TextField("請輸入指令...", text: $viewModel.inputText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isProcessing)
                    
                    Button(action: {
                        Task {
                            await viewModel.handleUserVoiceOrTextInput(modelContext: modelContext)
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(viewModel.inputText.isEmpty ? Color.gray : Color.blue)
                            .clipShape(Circle())
                    }
                    .disabled(viewModel.inputText.isEmpty || viewModel.isProcessing)
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("智慧管家")
            // 當 View 第一次渲染時，非同步呼叫自動排程大腦
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
}

#Preview {
    DashboardView()
        .modelContainer(for: [Expense.self, Event.self, TodoTask.self], inMemory: true)
}
