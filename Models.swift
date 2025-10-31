// PlannerEvent.swift
import Foundation
import SwiftUI

// Pomodoro oturum kaydı (opsiyonel)
struct PomodoroSession: Hashable, Codable {
    var id: UUID = UUID()
    var start: Date
    var durationMinutes: Int
    var completed: Bool
}

// Tekrarlama kuralı (opsiyonel)
struct RecurrenceRule: Hashable, Codable {
    enum Frequency: String, CaseIterable, Codable { case none, daily, weekly, monthly }
    var frequency: Frequency = .none     // none → tekrarsız
    var interval: Int = 1                // her 1 gün/hafta/ay
    /// Calendar weekday: 1=Pazar, …, 7=Cumartesi (iOS Calendar standardı)
    var weekdays: Set<Int> = []
    var until: Date? = nil
    var isEnabled: Bool { frequency != .none }
}

/// Uygulamadaki ana event/görev modeli
struct PlannerEvent: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var title: String
    var startDate: Date
    var endDate: Date
    var color: String            // "blue", "green" ...
    var notes: String
    var tag: String              // etiket
    var project: String          // proje
    var task: String             // "To Do" / "In Progress" / "Done"
    
    // —— Yeni alanlar (hepsi opsiyonel, mevcut veriyi bozmaz) ——
    var assignee: String? = nil          // görevi alan kişi
    var parentID: UUID? = nil            // üst görev id’si
    var recurrence: RecurrenceRule? = nil
    var pomodoroSessions: [PomodoroSession] = []
    
    // MARK: – Yardımcılar
    var isTask: Bool { startDate == endDate }   // görev → tek zamanlı
    var eventColor: Color {
        switch color.lowercased() {
        case "blue":   return .blue
        case "green":  return .green
        case "red":    return .red
        case "orange": return .orange
        case "purple": return .purple
        case "pink":   return .pink
        default:       return .blue
        }
    }
    var tagProjectTask: String {
        let parts = [tag, project, task].filter { !$0.isEmpty }
        return parts.joined(separator: " • ")
    }
    
    // Varsayılanları koruyan init (eski çağrılar kırılmasın diye)
    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        color: String = "blue",
        notes: String = "",
        tag: String = "",
        project: String = "",
        task: String = "",
        assignee: String? = nil,
        parentID: UUID? = nil,
        recurrence: RecurrenceRule? = nil,
        pomodoroSessions: [PomodoroSession] = []
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.color = color
        self.notes = notes
        self.tag = tag
        self.project = project
        self.task = task
        self.assignee = assignee
        self.parentID = parentID
        self.recurrence = recurrence
        self.pomodoroSessions = pomodoroSessions
    }
}

// (İsteğe bağlı) Saat çizgileri için kullandığın model
struct TimeSlot: Identifiable, Codable {
    let id = UUID()
    let hour: Int
    var timeString: String { String(format: "%02d:00", hour) }
}

// Görünüm modu
enum PlannerViewMode { case weekly, daily }
