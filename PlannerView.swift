// PlannerView.swift
import SwiftUI

// Uygulamada zaten varsa bunu kaldırabilirsin.

struct PlannerView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var dataStore: DataStore

    @State private var viewMode: PlannerViewMode = .weekly
    @State private var events: [PlannerEvent] = []
    @State private var selectedDate = Date()

    // Sheet / popup
    @State private var showingKanban = false
    @State private var showingCalendar = false
    @State private var showingEventForm = false

    // Form başlangıç bilgileri
    @State private var eventFormDate: Date?
    @State private var eventFormHour: Int?
    @State private var editingEvent: PlannerEvent?

    // Filtreler (Weekly/Daily'e iletiliyor)
    @State private var selectedTag: String? = nil
    @State private var selectedProject: String? = nil

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private let controlSize: CGFloat = 34
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                toolbarView
                Divider()
                
                if viewMode == .weekly {
                    WeeklyView(
                        events: $events,
                        selectedDate: $selectedDate,
                        selectedTag: $selectedTag,
                        selectedProject: $selectedProject,
                        onAddEvent: { date, hour in
                            eventFormDate = date
                            eventFormHour = hour
                            editingEvent = nil
                            showingEventForm = true
                        },
                        onEditEvent: { event in
                            editingEvent = event
                            showingEventForm = true
                        }
                    )
                } else {
                    DailyView(
                        events: $events,
                        selectedDate: $selectedDate,
                        selectedTag: $selectedTag,
                        selectedProject: $selectedProject,
                        onAddEvent: { date, hour in
                            eventFormDate = date
                            eventFormHour = hour
                            editingEvent = nil
                            showingEventForm = true
                        },
                        onEditEvent: { event in
                            editingEvent = event
                            showingEventForm = true
                        }
                    )
                }
            }
            
            // Takvim popup
            if showingCalendar {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { showingCalendar = false }
                
                CalendarPickerView(selectedDate: $selectedDate, isPresented: $showingCalendar)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        // Kanban
        .sheet(isPresented: $showingKanban) {
            KanbanView(
                events: $events,
                selectedTag: $selectedTag,
                selectedProject: $selectedProject,
                onAddEvent: {
                    // Kanban’dan + ile ekleme
                    editingEvent = nil
                    showingEventForm = true
                },
                onEditEvent: { event in
                    editingEvent = event
                    showingEventForm = true
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // Form
        .sheet(isPresented: $showingEventForm) {
            if let editingEvent {
                EventFormView(
                    isPresented: $showingEventForm,
                    editingEvent: editingEvent,
                    allEvents: events,
                    allTags: allTags(),
                    allProjects: allProjects(),
                    // pomodoroProvider: { id in [] } // bağlamak istersen
                    onSave: { updated in
                        dataStore.updateTask(updated)
                        self.editingEvent = nil
                        loadEvents()
                    },
                    onDelete: { e in
                        dataStore.deleteTask(e)
                        self.editingEvent = nil
                        loadEvents()
                    }
                )
            } else {
                EventFormView(
                    isPresented: $showingEventForm,
                    initialDate: eventFormDate,
                    initialHour: eventFormHour,
                    allEvents: events,
                    allTags: allTags(),
                    allProjects: allProjects(),
                    onSave: { newEvent in
                        dataStore.addTask(newEvent)
                        self.editingEvent = nil
                        loadEvents()
                    }
                )
            }
        }
        .onAppear {
            loadEvents()
            if events.isEmpty {
                loadSampleData()
            }
        }
        .onChange(of: dataStore.tasks) { _ in
            loadEvents()
        }
    }
    
    // MARK: - Toolbar (telefon & tablet ortak)
    private var toolbarView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Text("Planner")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(minWidth: 100, alignment: .leading)
                
                Spacer()
                
                HStack(spacing: 8) {
                    squareButton(systemName: "square.grid.2x2") { showingKanban = true }
                    squareButton(systemName: "arrow.clockwise", action: refreshData)
                    squareButton(systemName: "square.and.arrow.up", action: backupData)
                }
                .frame(minWidth: 100, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            
            // Week/Day anahtar + Takvim
            HStack(spacing: 8) {
                WeekDaySwitch(viewMode: $viewMode)
                Spacer()
                squareButton(systemName: "calendar") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showingCalendar = true }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .padding(.top, 8)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Helpers
    private func squareButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary.opacity(0.85))
                .frame(width: controlSize, height: controlSize)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    private func loadEvents() {
        events = dataStore.getPlannerEvents()
    }

    private func refreshData() {
        withAnimation {
            dataStore.fetchTasks()
            loadEvents()
        }
    }

    private func backupData() {
        print("Veriler yedekleniyor...")
        // Export to JSON for backup
        if let data = try? JSONEncoder().encode(events) {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let backupPath = documentsPath.appendingPathComponent("planner_backup_\(Date().timeIntervalSince1970).json")
            try? data.write(to: backupPath)
            print("Backup saved to: \(backupPath)")
        }
    }
    
    private func allTags() -> [String] {
        Array(Set(events.map { $0.tag }.filter { !$0.isEmpty })).sorted()
    }
    private func allProjects() -> [String] {
        Array(Set(events.map { $0.project }.filter { !$0.isEmpty })).sorted()
    }
    
    private func loadSampleData() {
        let calendar = Calendar.current
        let now = Date()
        let sampleEvents = [
            PlannerEvent(
                title: "Sabah Toplantısı",
                startDate: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!,
                endDate:   calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!,
                color: "blue", notes: "Haftalık planlama",
                tag: "Önemli", project: "Team Sync", task: "To Do"
            ),
            PlannerEvent(
                title: "Öğle Yemeği",
                startDate: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: now)!,
                endDate:   calendar.date(bySettingHour: 13, minute: 30, second: 0, of: now)!,
                color: "green", notes: "",
                tag: "Kişisel", project: "", task: "To Do"
            ),
            PlannerEvent(
                title: "Rapor Hazırla",
                startDate: calendar.startOfDay(for: now),
                endDate:   calendar.startOfDay(for: now),
                color: "purple", notes: "Q4 raporu",
                tag: "İş", project: "Raporlar", task: "To Do"
            ),
            PlannerEvent(
                title: "Kod Review",
                startDate: calendar.startOfDay(for: now),
                endDate:   calendar.startOfDay(for: now),
                color: "orange", notes: "PR #123",
                tag: "İş", project: "iOS App", task: "In Progress"
            )
        ]

        // Add sample events to DataStore
        for event in sampleEvents {
            dataStore.addTask(event)
        }
        loadEvents()
    }
}

// MARK: - Week/Day: Tamamen yuvarlak, Liquid Glass anahtar
struct WeekDaySwitch: View {
    @Binding var viewMode: PlannerViewMode
    
    private let height: CGFloat = 36
    private let spacing: CGFloat = 6
    
    var body: some View {
        HStack(spacing: spacing) {
            pill("Week", isOn: viewMode == .weekly) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewMode = .weekly }
            }
            pill("Day",  isOn: viewMode == .daily) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewMode = .daily }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: height)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
    
    private func pill(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isOn ? .blue : .primary.opacity(0.75))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(isOn ? Capsule().fill(Color.blue.opacity(0.14)) : nil)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

#Preview {
    PlannerView(selectedTab: .constant(0))
}
