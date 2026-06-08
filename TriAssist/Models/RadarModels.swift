//
//  RadarModels.swift
//  TriAssist
//

import Foundation
import MapKit
import SwiftUI

struct POIAnnotation: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
    let matchedItems: [String]
    let distance: Double

    var coordinate: CLLocationCoordinate2D { mapItem.placemark.coordinate }
    var name: String { mapItem.name ?? "未知地點" }

    var distanceText: String {
        distance < 1000
            ? String(format: "%.0f m", distance)
            : String(format: "%.1f km", distance / 1000)
    }

    var aiDescription: String = ""

    var walkingMinutes: Int { max(1, Int(distance / 83.0)) }

    var stayMinutes: Int {
        let perItem = matchedItems.count * 3
        switch categoryIcon {
        case "cart.fill":           return 5 + perItem
        case "basket.fill":         return 10 + perItem
        case "cross.fill":          return 8 + perItem
        case "book.fill":           return 15 + perItem
        case "pencil":              return 8 + perItem
        case "cup.and.saucer.fill": return 20
        case "fork.knife":          return 30
        case "envelope.fill":       return 10
        case "creditcard.fill":     return 5
        default:                    return 5 + perItem
        }
    }

    var estimatedMinutes: Int { walkingMinutes + stayMinutes }

    var estimatedTimeText: String {
        let t = estimatedMinutes
        if t < 60 { return "約 \(t) 分鐘" }
        let m = t % 60
        return m == 0 ? "約 \(t / 60) 小時" : "約 \(t / 60) 小時 \(m) 分"
    }

    var address: String? {
        let p = mapItem.placemark
        let parts = [p.subThoroughfare, p.thoroughfare, p.subLocality]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? p.locality : parts.joined(separator: " ")
    }

    var phone: String? { mapItem.phoneNumber?.isEmpty == false ? mapItem.phoneNumber : nil }

    var categoryLabel: String {
        let n = name.lowercased()
        if n.contains("超商") || n.contains("7-eleven") || n.contains("全家") || n.contains("便利") { return "便利商店" }
        if n.contains("全聯") { return "超市" }
        if n.contains("藥局") || n.contains("藥妝") || n.contains("屈臣") || n.contains("康是美") { return "藥局 / 藥妝" }
        if n.contains("書局") || n.contains("書店") || n.contains("誠品") { return "書店" }
        if n.contains("文具") { return "文具店" }
        if n.contains("超市") || n.contains("大潤發") || n.contains("家樂福") || n.contains("costco") { return "大型超市" }
        if n.contains("咖啡") || n.contains("cafe") || n.contains("coffee") { return "咖啡廳" }
        if n.contains("餐廳") || n.contains("美食") || n.contains("小吃") { return "餐飲" }
        if n.contains("郵局") { return "郵局" }
        if n.contains("銀行") || n.contains("atm") { return "銀行 / ATM" }
        return "商店"
    }

    var categoryIcon: String {
        let n = name.lowercased()
        if n.contains("超商") || n.contains("7-eleven") || n.contains("全家") || n.contains("全聯") || n.contains("便利") { return "cart.fill" }
        if n.contains("藥局") || n.contains("藥妝") || n.contains("屈臣") || n.contains("康是美") { return "cross.fill" }
        if n.contains("書局") || n.contains("書店") || n.contains("誠品") { return "book.fill" }
        if n.contains("文具") { return "pencil" }
        if n.contains("超市") || n.contains("大潤發") || n.contains("家樂福") || n.contains("costco") { return "basket.fill" }
        if n.contains("咖啡") || n.contains("cafe") || n.contains("coffee") { return "cup.and.saucer.fill" }
        if n.contains("餐廳") || n.contains("美食") || n.contains("小吃") { return "fork.knife" }
        if n.contains("郵局") { return "envelope.fill" }
        if n.contains("銀行") || n.contains("atm") { return "creditcard.fill" }
        return "mappin.circle.fill"
    }

    var categoryColor: Color {
        switch categoryIcon {
        case "cart.fill": return .blue
        case "cross.fill": return .red
        case "book.fill": return .orange
        case "pencil": return .purple
        case "basket.fill": return .green
        case "cup.and.saucer.fill": return .brown
        case "fork.knife": return .pink
        case "envelope.fill": return .indigo
        case "creditcard.fill": return .teal
        default: return .gray
        }
    }
}

