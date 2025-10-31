import Foundation
import SwiftUI

// MARK: - Date Extensions
extension Date {
    /// Tarihin hafta başlangıcını döndürür
    func startOfWeek(using calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    /// Tarihin hafta sonunu döndürür
    func endOfWeek(using calendar: Calendar = .current) -> Date {
        let startOfWeek = self.startOfWeek(using: calendar)
        return calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? self
    }
    
    /// Tarihin gün başlangıcını döndürür
    func startOfDay(using calendar: Calendar = .current) -> Date {
        return calendar.startOfDay(for: self)
    }
    
    /// Belirtilen saati ekler
    func addingHours(_ hours: Int, using calendar: Calendar = .current) -> Date {
        return calendar.date(byAdding: .hour, value: hours, to: self) ?? self
    }
    
    
}

// MARK: - Event Manager
class EventManager: ObservableObject {
    @Published var events: [PlannerEvent] = []
    
    
    // Event ekle
    func addEvent(_ event: PlannerEvent) {
        events.append(event)
        saveEvents()
    }
    
    // Event güncelle
    func updateEvent(_ event: PlannerEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
            saveEvents()
        }
    }
    
    // Event sil
    func deleteEvent(_ event: PlannerEvent) {
        events.removeAll { $0.id == event.id }
        saveEvents()
    }
    
    // Belirli bir gün için eventleri getir
    func eventsForDate(_ date: Date) -> [PlannerEvent] {
        events.filter { event in
            Calendar.current.isDate(event.startDate, inSameDayAs: date)
        }
        .sorted { $0.startDate < $1.startDate }
    }
    
    // Belirli bir zaman aralığı için eventleri getir
    func eventsInRange(from startDate: Date, to endDate: Date) -> [PlannerEvent] {
        events.filter { event in
            event.startDate >= startDate && event.startDate <= endDate
        }
        .sorted { $0.startDate < $1.startDate }
    }
    
    // MARK: - Persistence (Local Storage)
    private func saveEvents() {
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: "plannerEvents")
        }
    }
    
    func loadEvents() {
        if let data = UserDefaults.standard.data(forKey: "plannerEvents"),
           let decoded = try? JSONDecoder().decode([PlannerEvent].self, from: data) {
            events = decoded
        }
    }
    
    
}

// MARK: - Color Extensions
extension Color {
    /// Hex string’den renk oluştur
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    
    /// Rengi hex string'e çevir
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
    }
    
    
}

// MARK: - Time Utilities
struct TimeUtilities {
    /// Bir günün tüm saat dilimlerini döndürür
    static func hoursInDay() -> [Int] {
        return Array(0...23)
    }
    
    
    /// İki tarih arasındaki süreyi saat cinsinden döndürür
    static func hoursBetween(start: Date, end: Date) -> Double {
        return end.timeIntervalSince(start) / 3600
    }
    
    /// İki tarihin aynı gün olup olmadığını kontrol eder
    static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return Calendar.current.isDate(date1, inSameDayAs: date2)
    }
    
    
}

// MARK: - Validation
struct EventValidator {
    /// Event’in geçerli olup olmadığını kontrol eder
    static func isValid(_ event: PlannerEvent) -> Bool {
        // Başlangıç bitiş tarihinden önce olmalı
        guard event.startDate < event.endDate else { return false }
        
        
        // Başlık boş olmamalı
        guard !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        
        return true
    }
    
    /// İki event'in çakışıp çakışmadığını kontrol eder
    static func hasConflict(_ event1: PlannerEvent, _ event2: PlannerEvent) -> Bool {
        // Aynı günde değillerse çakışma yok
        guard Calendar.current.isDate(event1.startDate, inSameDayAs: event2.startDate) else {
            return false
        }
        
        // Zaman çakışması kontrolü
        return event1.startDate < event2.endDate && event2.startDate < event1.endDate
    }
    
    
}

extension View {
    /// iOS 17+ uyumlu "liquid glass" görünümü.
    /// İçeriği cam gibi gösterir, kenar çizgisi ve gölge ekler.
    func liquidGlassBackground<S: Shape>(in shape: S) -> some View {
        self
            .background(.ultraThinMaterial, in: shape)                    // cam efekti
            .overlay(shape.stroke(.white.opacity(0.22), lineWidth: 1))    // kenar çizgisi
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)  // yüzen gölge
    }
}
