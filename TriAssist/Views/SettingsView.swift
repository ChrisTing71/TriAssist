//
//  SettingsView.swift
//  TriAssist
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedAIEngine") private var selectedEngine: AIEngine = .cloud
    @AppStorage("customApiKey")     private var apiKey: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("AI 核心驅動引擎設定")) {
                    Picker("處理核心", selection: $selectedEngine) {
                        Text("雲端高效能 AI (預設)").tag(AIEngine.cloud)
                        Text("Apple Intelligence (地端)").tag(AIEngine.apple)
                    }
                    .pickerStyle(.inline)
                    .onChange(of: selectedEngine) { _, newValue in
                        UserDefaults.standard.set(newValue.rawValue, forKey: "selectedAIEngine")
                    }

                    if selectedEngine == .cloud {
                        HStack {
                            Image(systemName: "key.fill").foregroundColor(.orange)
                            SecureField("Gemini API Key", text: $apiKey)
                        }
                    } else {
                        HStack {
                            Image(systemName: "apple.intelligence").foregroundStyle(.gray)
                            Text("已使用 iPhone 本地神經網路，資料不上傳雲端。")
                                .font(.caption).foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
