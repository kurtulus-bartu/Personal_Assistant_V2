import SwiftUI

struct WeeklyView: View {
    @Binding var events: [PlannerEvent]
    @Binding var selectedDate: Date
    @Binding var selectedTag: String?
    @Binding var selectedProject: String?
    var onAddEvent: ((Date, Int) -> Void)?
    var onEditEvent: ((PlannerEvent) -> Void)?
    
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var scrollPosition: Int?
    
    private let hours = Array(0...23)
    private let hourHeight: CGFloat = 60
    private let calendar = Calendar.current
    
    private var numberOfDays: Int {
        return horizontalSizeClass == .regular ? 7 : 3
    }
    
    // Sadece etkinlikleri filtrele (başlangıç zamanı olan)
    private var filteredEvents: [PlannerEvent] {
        events.filter { event in
            // Sadece başlangıç zamanı olan etkinlikler
            guard event.startDate != event.endDate else { return false }
            
            var matches = true
            if let tag = selectedTag, !tag.isEmpty {
                matches = matches && event.tag == tag
            }
            if let project = selectedProject, !project.isEmpty {
                matches = matches && event.project == project
            }
            return matches
        }
    }
    
    private var weekStartDate: Date {
        if horizontalSizeClass == .regular {
            let weekday = calendar.component(.weekday, from: selectedDate)
            let daysToMonday = weekday == 1 ? -6 : 2 - weekday
            return calendar.date(byAdding: .day, value: daysToMonday, to: selectedDate) ?? selectedDate
        } else {
            return selectedDate
        }
    }
    
    private var allDays: [Date] {
        var days: [Date] = []
        let baseDate = weekStartDate
        
        for weekOffset in -4...4 {
            for dayOffset in 0..<7 {
                let totalDayOffset = (weekOffset * 7) + dayOffset
                if let date = calendar.date(byAdding: .day, value: totalDayOffset, to: baseDate) {
                    days.append(date)
                }
            }
        }
        
        return days
    }
    
    private var groupedDays: [[Date]] {
        stride(from: 0, to: allDays.count, by: numberOfDays).map {
            let endIndex = min($0 + numberOfDays, allDays.count)
            return Array(allDays[$0..<endIndex])
        }
    }
    
    private func pageIndexForDate(_ date: Date) -> Int? {
        for (index, dayGroup) in groupedDays.enumerated() {
            if dayGroup.contains(where: { calendar.isDate($0, inSameDayAs: date) }) {
                return index
            }
        }
        return nil
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 50)
                        
                        HStack(alignment: .top, spacing: 0) {
                            timeColumn
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 0) {
                                    ForEach(0..<groupedDays.count, id: \.self) { pageIndex in
                                        pageView(
                                            for: groupedDays[pageIndex],
                                            width: geometry.size.width - 50
                                        )
                                        .id(pageIndex)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.paging)
                            .scrollPosition(id: $scrollPosition)
                        }
                    }
                }
                
                HStack(spacing: 0) {
                    Color.clear.frame(width: 50)
                    
                    if let currentPage = scrollPosition, currentPage < groupedDays.count {
                        let pageWidth = (geometry.size.width - 50) / CGFloat(numberOfDays)
                        HStack(spacing: 0) {
                            ForEach(groupedDays[currentPage], id: \.self) { day in
                                dayHeader(for: day)
                                    .frame(width: pageWidth)
                            }
                        }
                    }
                }
                .frame(height: 50)
                .background(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
            }
            .onAppear {
                if let targetPage = pageIndexForDate(weekStartDate) {
                    scrollPosition = targetPage
                }
            }
            .onChange(of: selectedDate) { oldValue, newValue in
                let targetDate = horizontalSizeClass == .regular ? weekStartDate : newValue
                if let targetPage = pageIndexForDate(targetDate) {
                    withAnimation {
                        scrollPosition = targetPage
                    }
                }
            }
        }
        .background(Color(UIColor.systemBackground))
    }
    
    private var timeColumn: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                VStack(spacing: 0) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(height: 20)
                    Spacer()
                }
                .frame(width: 50, height: hourHeight)
            }
        }
    }
    
    private func pageView(for days: [Date], width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                dayColumn(for: day, width: width / CGFloat(numberOfDays))
            }
        }
        .frame(width: width)
    }
    
    private func dayColumn(for date: Date, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(hours, id: \.self) { hour in
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)
                        Color.clear
                            .frame(height: hourHeight - 1)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                onAddEvent?(date, hour)
                            }
                    }
                }
            }
            
            ForEach(eventsForDay(date)) { event in
                eventView(event, for: date)
                    .onTapGesture(count: 2) {
                        onEditEvent?(event)
                    }
            }
        }
        .frame(width: width)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1),
            alignment: .trailing
        )
    }
    
    private func dayHeader(for date: Date) -> some View {
        VStack(spacing: 2) {
            Text(date.formatted(.dateTime.day()) + " " + date.formatted(.dateTime.month(.abbreviated)))
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.subheadline)
                .fontWeight(calendar.isDateInToday(date) ? .bold : .medium)
                .foregroundColor(calendar.isDateInToday(date) ? .blue : .primary)
        }
        .frame(maxWidth: .infinity)
        .background(calendar.isDateInToday(date) ? Color.blue.opacity(0.1) : .clear)
    }
    
    private func eventView(_ event: PlannerEvent, for date: Date) -> some View {
        let startHour = calendar.component(.hour, from: event.startDate)
        let startMinute = calendar.component(.minute, from: event.startDate)
        let duration = event.endDate.timeIntervalSince(event.startDate) / 3600
        
        let topOffset = CGFloat(startHour) * hourHeight + (CGFloat(startMinute) / 60.0) * hourHeight
        let height = CGFloat(duration) * hourHeight
        
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(numberOfDays == 7 ? 1 : 2)

                if !event.pomodoroSessions.isEmpty {
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "timer")
                            .font(.system(size: 8))
                        Text("\(event.pomodoroSessions.count)")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.blue.opacity(0.8))
                }
            }

            if !event.tagProjectTask.isEmpty && height > 40 {
                Text(event.tagProjectTask)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: max(height - 4, 30))
        .background(Color(hex: "#2d2d2d"))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(hex: "#1a1a1a"), lineWidth: 1)
        )
        .cornerRadius(6)
        .padding(.horizontal, 2)
        .offset(y: topOffset)
    }
    
    private func eventsForDay(_ date: Date) -> [PlannerEvent] {
        filteredEvents.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: date)
        }
    }
    
    
}

#Preview {
    WeeklyView(
        events: .constant([]),
        selectedDate: .constant(Date()),
        selectedTag: .constant(nil),
        selectedProject: .constant(nil),
        onAddEvent: nil,
        onEditEvent: nil
    )
}
