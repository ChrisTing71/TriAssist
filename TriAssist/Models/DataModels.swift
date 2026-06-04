//
//  DataModels.swift
//  TriAssist
//
//  Created by 丁帥 on 2026/6/4.
//

import Foundation
import SwiftData

@Model
final class Expense {
    var id: UUID
    var item: String
    var amount: Double
    var category: String
    var date: Date
    
    init(item: String, amount: Double, category: String, date: Date = Date()) {
        self.id = UUID()
        self.item = item
        self.amount = amount
        self.category = category
        self.date = date
    }
}

@Model
final class Event {
    var id: UUID
    var title: String
    var startTime: Date
    var endTime: Date
    
    init(title: String, startTime: Date, endTime: Date) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
    }
}

@Model
final class TodoTask {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var dueDate: Date?
    
    init(title: String, isCompleted: Bool = false, dueDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
    }
}
