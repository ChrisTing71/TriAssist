//
//  SettingsView.swift
//  TriAssist
//
//  Created by 丁帥 on 2026/6/4.
//

import SwiftUI

struct SettingsView: View {
    // 透過監聽與 ViewModel 一致的 AppStorage，達成跨頁面的設定即時持久化連動
    @AppStorage("selectedAIEngine") private var selectedEngine: AIEngine = .cloud
    @AppStorage("customApiKey") private var apiKey: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                // 區塊一：AI 引擎切換核心後台
                Section(header: Text("AI 核心驅動引擎設定")) {
                    Picker("處理核心", selection: $selectedEngine) {
                        Text("雲端高智能 AI (預設)").tag(AIEngine.cloud)
                        Text("Apple Intelligence (地端)").tag(AIEngine.apple)
                    }
                    .pickerStyle(.inline) // 展開清單方便快速點選
                    .onChange(of: selectedEngine) { oldValue, newValue in
                                            UserDefaults.standard.set(newValue.rawValue, forKey: "selectedAIEngine")
                                        }
                    if selectedEngine == .cloud {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.orange)
                            SecureField("請輸入您的 OpenAI API Key", text: $apiKey)
                        }
                    } else {
                        HStack {
                            Image(systemName: "apple.intelligence")
                                .foregroundStyle(.gray)
                            Text("已鎖定 iPhone 本地神經網路大模型。資料絕不上雲、離線完全可用且注重個人隱私。")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // 區塊二：期末專案團隊與上架資訊資訊
                Section(header: Text("關於我們")) {
                    HStack {
                        Text("專案名稱")
                        Spacer()
                        Text("TriAssist")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("開發團隊")
                        Spacer()
                        Text("111590022 丁勇智")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("系統設定")
        }
    }
}

#Preview {
    SettingsView()
}
