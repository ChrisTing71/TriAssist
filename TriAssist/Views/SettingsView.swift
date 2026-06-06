//
//  SettingsView.swift
//  TriAssist
//

import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @AppStorage("selectedAIEngine") private var selectedEngine: AIEngine = .cloud
    @AppStorage("customApiKey")     private var apiKey: String = ""
    @State private var showSignOutConfirm = false
    @State private var isSigningInWithApple = false

    var body: some View {
        NavigationStack {
            Form {
                // Account section
                if authManager.isLoggedIn {
                    loggedInSection
                } else {
                    signInSection
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

                // About
                Section(header: Text("關於我們")) {
                    infoRow("專案名稱", value: "TriAssist")
                    infoRow("開發團隊", value: "111590022 丁勇智 · 110590057 蔡昀祐")
                }
            }
            .navigationTitle("Settings")
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
                            .fill(user.provider == .apple ? Color(.systemGray5) : Color.blue.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Text(user.initials)
                            .font(.title3).bold()
                            .foregroundColor(user.provider == .apple ? .primary : .blue)
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
            // Sign in with Apple
            ZStack(alignment: .leading) {
                SignInWithAppleButton(.signIn, onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                    authManager.errorMessage = ""
                    isSigningInWithApple = true
                }, onCompletion: { result in
                    Task { @MainActor in
                        isSigningInWithApple = false
                        authManager.handleAppleSignInResult(result)
                    }
                })
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)
                .cornerRadius(10)
                .disabled(isSigningInWithApple || authManager.isLoading)

                if isSigningInWithApple {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.85))
                        .frame(height: 44)
                    HStack { Spacer(); ProgressView().tint(.white); Spacer() }
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            // Sign in with Google
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
            .disabled(isSigningInWithApple || authManager.isLoading)

            // Error message
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

    // MARK: - Helpers
    @ViewBuilder
    private func providerBadge(_ provider: AuthProvider) -> some View {
        HStack(spacing: 4) {
            Image(systemName: provider == .apple ? "apple.logo" : "g.circle.fill")
                .font(.caption)
            Text(provider.rawValue)
                .font(.caption2).fontWeight(.semibold)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
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
