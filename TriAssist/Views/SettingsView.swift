//
//  SettingsView.swift
//  TriAssist
//

import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @AppStorage("selectedAIEngine") private var selectedEngine: AIEngine = .cloud
    @AppStorage("customApiKey")     private var apiKey: String = ""
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                // User profile card
                if let user = authManager.currentUser {
                    profileSection(user)
                }

                // AI engine settings
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

                // Google Sign-In config
                Section(header: Text("Google 登入設定")) {
                    HStack {
                        Image(systemName: "key.fill").foregroundColor(.blue)
                        @Bindable var manager = authManager
                        TextField("Google Client ID", text: $manager.googleClientId)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    Text("格式：xxxxxxx.apps.googleusercontent.com\n需在 Google Cloud Console 建立 OAuth 2.0 iOS 用戶端 ID。")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // About
                Section(header: Text("關於我們")) {
                    infoRow("專案名稱", value: "TriAssist")
                    infoRow("開發團隊", value: "111590022 丁勇智 · 110590057 蔡昀祐")
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("登出")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("確定要登出嗎？", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("登出", role: .destructive) { authManager.signOut() }
                Button("取消", role: .cancel) { }
            }
        }
    }

    // MARK: - Profile section
    @ViewBuilder
    private func profileSection(_ user: UserProfile) -> some View {
        Section {
            HStack(spacing: 14) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(user.provider == .apple ? Color(.systemGray5) : Color.blue.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Text(user.initials)
                        .font(.title3).bold()
                        .foregroundColor(user.provider == .apple ? .primary : .blue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(user.displayName)
                        .font(.headline)
                    if !user.email.isEmpty {
                        Text(user.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Provider badge
                providerBadge(user.provider)
            }
            .padding(.vertical, 4)
        } header: {
            Text("使用者資料")
        }
    }

    @ViewBuilder
    private func providerBadge(_ provider: AuthProvider) -> some View {
        HStack(spacing: 4) {
            Image(systemName: provider == .apple ? "apple.logo" : "g.circle.fill")
                .font(.caption)
            Text(provider.rawValue)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .foregroundColor(.secondary)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundColor(.secondary).font(.caption)
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthManager())
}
