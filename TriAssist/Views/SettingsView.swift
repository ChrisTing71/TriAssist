//
//  SettingsView.swift
//  TriAssist
//

import SwiftUI
import TipKit

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(RoutineManager.self) private var routineManager
    @AppStorage("selectedAIEngine") private var selectedEngine: AIEngine = .cloud
    @AppStorage("customApiKey")     private var apiKey: String = ""
    @State private var showSignOutConfirm = false
    @State private var showRoutineEditor = false
    private let routineTip = RoutineSettingsTip()

    var body: some View {
        NavigationStack {
            Form {
                if authManager.isLoggedIn {
                    loggedInSection
                } else {
                    signInSection
                }

                Section(header: Text("固定行程")) {
                    Button {
                        showRoutineEditor = true
                        routineTip.invalidate(reason: .actionPerformed)
                    } label: {
                        HStack {
                            Label("每日 / 每週固定行程", systemImage: "calendar.badge.clock")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    .popoverTip(routineTip)
                }

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
            .sheet(isPresented: $showRoutineEditor) {
                RoutineEditorView()
                    .environment(routineManager)
            }
            .confirmationDialog("確定要登出嗎？", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("登出", role: .destructive) { authManager.signOut() }
                Button("取消", role: .cancel) { }
            }
        }
    }

    // MARK: - Logged-in profile
    private var loggedInSection: some View {
        Section(header: Text("帳號")) {
            if let user = authManager.currentUser {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Text(user.initials)
                            .font(.title3).bold()
                            .foregroundColor(.blue)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(user.displayName).font(.headline)
                        if !user.email.isEmpty {
                            Text(user.email).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    providerBadge(user.provider)
                }
                .padding(.vertical, 4)
            }

            Button(role: .destructive) {
                showSignOutConfirm = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("登出")
                }
            }
        }
    }

    // MARK: - Sign-in buttons
    private var signInSection: some View {
        Section(header: Text("帳號"), footer: signInFooter) {
            Button {
                authManager.errorMessage = ""
                Task { await authManager.signInWithGoogle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(.systemBackground)).frame(width: 22, height: 22)
                        Text("G")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .red, .yellow, .green],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                    }
                    if authManager.isLoading {
                        ProgressView().tint(.primary)
                        Text("登入中...").foregroundColor(.secondary)
                    } else {
                        Text("Sign in with Google")
                            .foregroundColor(.primary)
                    }
                }
            }
            .disabled(authManager.isLoading)

            if !authManager.errorMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                    Text(authManager.errorMessage)
                        .font(.caption).foregroundColor(.red)
                }
            }
        }
    }

    private var signInFooter: some View {
        Text("登入後可顯示帳號資訊，資料仍儲存於本機。")
            .font(.caption)
    }

    private func providerBadge(_ provider: AuthProvider) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "g.circle.fill")
                .font(.caption)
            Text(provider.rawValue)
                .font(.caption2).fontWeight(.semibold)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .foregroundColor(.secondary)
    }
}

#Preview {
    SettingsView()
        .environment(AuthManager())
}
