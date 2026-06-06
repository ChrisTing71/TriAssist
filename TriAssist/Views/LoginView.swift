//
//  LoginView.swift
//  TriAssist
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var isSigningInWithApple = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo & Title
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue.gradient)
                    }
                    VStack(spacing: 6) {
                        Text("TriAssist")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("您的智慧生活管家")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: 14) {
                    // Sign in with Apple
                    ZStack {
                        SignInWithAppleButton(.signIn, onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                            authManager.errorMessage = ""
                            isSigningInWithApple = true
                        }, onCompletion: { result in
                            // Explicitly dispatch to MainActor to guarantee UI update
                            Task { @MainActor in
                                isSigningInWithApple = false
                                authManager.handleAppleSignInResult(result)
                            }
                        })
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .cornerRadius(14)
                        .disabled(isSigningInWithApple || authManager.isLoading)

                        // Show spinner inside button area while waiting
                        if isSigningInWithApple {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.black.opacity(0.85))
                                .frame(height: 52)
                            ProgressView().tint(.white)
                        }
                    }

                    // Sign in with Google
                    Button {
                        authManager.errorMessage = ""
                        Task { await authManager.signInWithGoogle() }
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(.white).frame(width: 24, height: 24)
                                Text("G")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .red, .yellow, .green],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            Text("Sign in with Google")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(.secondarySystemBackground))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 1))
                        .cornerRadius(14)
                    }
                    .disabled(isSigningInWithApple || authManager.isLoading)
                }
                .padding(.horizontal, 32)

                // Error message (shown for all auth errors)
                if !authManager.errorMessage.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(authManager.errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
                }

                Spacer().frame(height: 60)
            }

            // Google loading overlay
            if authManager.isLoading {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView().scaleEffect(1.4).tint(.white)
                        Text("Google 登入中...").foregroundColor(.white).font(.subheadline)
                    }
                    .padding(28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthManager())
}
