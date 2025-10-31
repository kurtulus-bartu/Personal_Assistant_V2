import SwiftUI

struct CalendarPickerView: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    
    @State private var displayMonth: Date
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    
    init(selectedDate: Binding<Date>, isPresented: Binding<Bool>) {
        self._selectedDate = selectedDate
        self._isPresented = isPresented
        self._displayMonth = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Başlık ve Aylar
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(displayMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Haftanın günleri
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Günler grid'i
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
            .padding(.horizontal, 8)
            
            // Bugün butonu
            Button(action: {
                selectedDate = Date()
                isPresented = false
            }) {
                Text("Bugün")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .frame(width: 320)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Day Cell
    private func dayCell(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isCurrentMonth = calendar.isDate(date, equalTo: displayMonth, toGranularity: .month)
        
        return Button(action: {
            selectedDate = date
            isPresented = false
        }) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16))
                .fontWeight(isToday || isSelected ? .bold : .regular)
                .foregroundColor(
                    isSelected ? .white :
                        isToday ? .blue :
                        isCurrentMonth ? .primary : .secondary
                )
                .frame(width: 40, height: 40)
                .background(
                    isSelected ? Color.blue :
                        isToday ? Color.blue.opacity(0.2) :
                        Color.clear
                )
                .cornerRadius(20)
        }
    }
    
    // MARK: - Ayın günleri
    private var daysInMonth: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth)),
              let monthRange = calendar.range(of: .day, in: .month, for: displayMonth) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let offsetDays = (firstWeekday == 1 ? 6 : firstWeekday - 2) // Pazartesi'den başla
        
        var days: [Date?] = Array(repeating: nil, count: offsetDays)
        
        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }
        
        return days
    }
    
    // MARK: - Navigation
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: displayMonth) {
            displayMonth = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: displayMonth) {
            displayMonth = newDate
        }
    }
    
}

#Preview {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
        
        CalendarPickerView(
            selectedDate: .constant(Date()),
            isPresented: .constant(true)
        )
    }
    
}
