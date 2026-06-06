//
//  AuthModels.swift
//  TriAssist
//

import Foundation

enum AuthProvider: String, Codable {
    case apple = "Apple"
    case google = "Google"
}

struct UserProfile: Codable, Equatable {
    let id: String
    let name: String
    let email: String
    let provider: AuthProvider

    var displayName: String { name.isEmpty ? (email.isEmpty ? "使用者" : email) : name }

    var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1)) + String(words[1].prefix(1))
        }
        return String(name.prefix(1)).uppercased().isEmpty ? "?" : String(name.prefix(1)).uppercased()
    }
}
