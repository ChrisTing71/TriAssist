//
//  AuthManager.swift
//  TriAssist
//

import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
@Observable
class AuthManager: NSObject {

    // MARK: - State
    var currentUser: UserProfile? = nil
    var isLoading = false
    var errorMessage = ""

    var isLoggedIn: Bool { currentUser != nil }

    private let googleClientId = "650304933460-ou75ngpcvpja4foqtnu9pcu4j2oc5e12.apps.googleusercontent.com"

    private var webAuthSession: ASWebAuthenticationSession?

    override init() {
        if let data = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            currentUser = user
        }
    }

    // MARK: - Sign in with Apple

    func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "無法取得 Apple 憑證，請重試。"
                return
            }

            var name = ""
            if let fullName = credential.fullName {
                let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }
                name = parts.joined(separator: " ")
            }
            if name.isEmpty, let saved = currentUser, saved.provider == .apple, saved.id == credential.user {
                name = saved.name
            }

            let user = UserProfile(
                id: credential.user,
                name: name.isEmpty ? "Apple 使用者" : name,
                email: credential.email ?? currentUser?.email ?? "",
                provider: .apple
            )
            saveUser(user)
            errorMessage = ""

        case .failure(let error):
            let code = (error as? ASAuthorizationError)?.code
            switch code {
            case .canceled:
                break
            case .unknown:
                errorMessage = "Sign in with Apple 未啟用。\n請在 Xcode → Signing & Capabilities 加入此功能，並確認模擬器已登入 iCloud。"
            default:
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Sign in with Google (PKCE via ASWebAuthenticationSession)

    func signInWithGoogle() async {
        guard !googleClientId.isEmpty else {
            errorMessage = "請先在「設定」中填入 Google Client ID"
            return
        }

        isLoading = true
        errorMessage = ""

        do {
            let codeVerifier = Self.generateCodeVerifier()
            let codeChallenge = Self.generateCodeChallenge(from: codeVerifier)

            let reversedId = googleClientId
                .replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
            let scheme = "com.googleusercontent.apps.\(reversedId)"
            let redirectUri = "\(scheme):/"

            var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
            components.queryItems = [
                .init(name: "client_id",             value: googleClientId),
                .init(name: "redirect_uri",          value: redirectUri),
                .init(name: "response_type",         value: "code"),
                .init(name: "scope",                 value: "openid email profile"),
                .init(name: "code_challenge",        value: codeChallenge),
                .init(name: "code_challenge_method", value: "S256"),
            ]
            guard let authURL = components.url else { throw URLError(.badURL) }

            let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
                let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { url, error in
                    if let url { cont.resume(returning: url) }
                    else { cont.resume(throwing: error ?? URLError(.cancelled)) }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = true
                webAuthSession = session
                session.start()
            }
            webAuthSession = nil

            guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value
            else { throw URLError(.cannotParseResponse) }

            let idToken = try await exchangeGoogleCode(
                code: code, redirectUri: redirectUri, codeVerifier: codeVerifier
            )

            let user = try Self.parseGoogleIdToken(idToken, clientId: googleClientId)
            saveUser(user)

        } catch let err as ASWebAuthenticationSessionError where err.code == .canceledLogin {
            // User pressed Cancel — not an error
        } catch {
            errorMessage = "Google 登入失敗：\(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Sign out

    func signOut() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "currentUser")
    }

    // MARK: - Helpers

    private func saveUser(_ user: UserProfile) {
        currentUser = user
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "currentUser")
        }
    }

    private func exchangeGoogleCode(code: String, redirectUri: String, codeVerifier: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params: [String: String] = [
            "grant_type":    "authorization_code",
            "code":          code,
            "redirect_uri":  redirectUri,
            "client_id":     googleClientId,
            "code_verifier": codeVerifier,
        ]
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        struct TokenResponse: Codable { let id_token: String? }
        let resp = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let idToken = resp.id_token else { throw URLError(.cannotParseResponse) }
        return idToken
    }

    private static func parseGoogleIdToken(_ token: String, clientId: String) throws -> UserProfile {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { throw URLError(.cannotParseResponse) }

        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }

        guard let data = Data(base64Encoded: b64) else { throw URLError(.cannotParseResponse) }

        struct Claims: Codable {
            let sub: String
            let name: String?
            let email: String?
            let given_name: String?
            let family_name: String?
        }
        let claims = try JSONDecoder().decode(Claims.self, from: data)
        let name = claims.name
            ?? [claims.given_name, claims.family_name].compactMap { $0 }.joined(separator: " ")

        return UserProfile(
            id: claims.sub,
            name: name.isEmpty ? "Google 使用者" : name,
            email: claims.email ?? "",
            provider: .google
        )
    }

    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private static func generateCodeChallenge(from verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncoded()
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows
                .first(where: { $0.isKeyWindow }) ?? UIWindow()
        }
    }
}

// MARK: - Data+base64URLEncoded
private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
