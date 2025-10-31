import SwiftUI

struct DailyView: View {
    @Binding var events: [PlannerEvent]
    @Binding var selectedDate: Date
    @Binding var selectedTag: String?
    @Binding var selectedProject: String?
    var onAddEvent: ((Date, Int) -> Void)?
    var onEditEvent: ((PlannerEvent) -> Void)?
    
    
    private let hours = Array(0...23)
    private let hourHeight: CGFloat = 60
    private let calendar = Calendar.current
    
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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 50)
                        
                        HStack(alignment: .top, spacing: 0) {
                            timeColumn
                            eventTimeline(width: geometry.size.width - 60)
                        }
                    }
                }
                
                HStack(spacing: 0) {
                    Color.clear.frame(width: 60)
                    
                    dayHeader
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 50)
                .background(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
            }
        }
        .background(Color(UIColor.systemBackground))
    }
    
    private var dayHeader: some View {
        VStack(spacing: 2) {
            Text(selectedDate.formatted(.dateTime.day()) + " " + selectedDate.formatted(.dateTime.month(.abbreviated)))
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(selectedDate.formatted(.dateTime.weekday(.abbreviated)))
                .font(.subheadline)
                .fontWeight(calendar.isDateInToday(selectedDate) ? .bold : .medium)
                .foregroundColor(calendar.isDateInToday(selectedDate) ? .blue : .primary)
        }
        .frame(maxWidth: .infinity)
        .background(calendar.isDateInToday(selectedDate) ? Color.blue.opacity(0.1) : .clear)
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
                .frame(width: 60, height: hourHeight)
            }
        }
    }
    
    private func eventTimeline(width: CGFloat) -> some View {
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
                                onAddEvent?(selectedDate, hour)
                            }
                    }
                }
            }
            
            if calendar.isDateInToday(selectedDate) {
                currentTimeLine
            }
            
            ForEach(todayEvents) { event in
                eventCard(event)
                    .onTapGesture(count: 2) {
                        onEditEvent?(event)
                    }
            }
        }
        .frame(width: width)
        .padding(.horizontal, 8)
    }
    
    private var currentTimeLine: some View {
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let offset = CGFloat(hour) * hourHeight + (CGFloat(minute) / 60.0) * hourHeight
        
        return HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(Color.red)
                .frame(height: 2)
        }
        .offset(y: offset)
    }
    
    private func eventCard(_ event: PlannerEvent) -> some View {
        let startHour = calendar.component(.hour, from: event.startDate)
        let startMinute = calendar.component(.minute, from: event.startDate)
        let duration = event.endDate.timeIntervalSince(event.startDate) / 3600
        
        let topOffset = CGFloat(startHour) * hourHeight + (CGFloat(startMinute) / 60.0) * hourHeight
        let height = CGFloat(duration) * hourHeight
        
        return VStack(alignment: .leading, spacing: 3) {
            Text(event.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(2)
            
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
        .padding(.horizontal, 4)
        .offset(y: topOffset)
    }
    
    private var todayEvents: [PlannerEvent] {
        filteredEvents.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: selectedDate)
        }
        .sorted { $0.startDate < $1.startDate }
    }
    
    
}

#Preview {
    DailyView(
        events: .constant([]),
        selectedDate: .constant(Date()),
        selectedTag: .constant(nil),
        selectedProject: .constant(nil),
        onAddEvent: nil,
        onEditEvent: nil
    )
}
