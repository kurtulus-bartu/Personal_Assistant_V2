// EventFormView.swift
import SwiftUI

// Alt panel sekmeleri
private enum DetailTab: String, CaseIterable {
    case notes = "Notlar"
    case subtasks = "Bağlantılı"
    case pomodoro = "Pomodoro"
}

struct EventFormView: View {
    @Binding var isPresented: Bool
    
    // Düzenleme
    var editingEvent: PlannerEvent? = nil
    
    // Seçim kaynakları
    var allEvents: [PlannerEvent] = []
    var allTags: [String] = []
    var allProjects: [String] = []
    
    // Opsiyonel: Pomodoro veri sağlayıcı
    var pomodoroProvider: ((UUID) -> [PomodoroSession])? = nil
    
    // Callbacks
    var onSave: ((PlannerEvent) -> Void)? = nil
    var onDelete: ((PlannerEvent) -> Void)? = nil
    
    // Form state
    @State private var title: String = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var taskDate: Date
    @State private var tag: String = ""
    @State private var project: String = ""
    @State private var taskStatus: String = "To Do"
    @State private var notes: String = ""
    @State private var isTask: Bool = false
    
    // Bağlantılı görev (üst görev)
    @State private var parentID: UUID? = nil
    
    // Tekrarlama
    @State private var recurrenceEnabled: Bool = false
    @State private var recurrenceFrequency: RecurrenceRule.Frequency = .none
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceUntil: Date? = nil
    @State private var weeklyDays: Set<Int> = []  // 1...7 (Calendar)
    
    // Alt panel sekmesi (sınırlı genişlik)
    @State private var detailTab: DetailTab = .notes
    
    private let taskOptions = ["To Do", "In Progress", "Done"]
    
    // Init
    init(
        isPresented: Binding<Bool>,
        editingEvent: PlannerEvent? = nil,
        initialDate: Date? = nil,
        initialHour: Int? = nil,
        allEvents: [PlannerEvent] = [],
        allTags: [String] = [],
        allProjects: [String] = [],
        pomodoroProvider: ((UUID) -> [PomodoroSession])? = nil,
        onSave: ((PlannerEvent) -> Void)? = nil,
        onDelete: ((PlannerEvent) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.editingEvent = editingEvent
        self.allEvents = allEvents
        self.allTags = allTags
        self.allProjects = allProjects
        self.pomodoroProvider = pomodoroProvider
        self.onSave = onSave
        self.onDelete = onDelete
        
        let cal = Calendar.current
        if let e = editingEvent {
            _title = State(initialValue: e.title)
            _startDate = State(initialValue: e.startDate)
            _endDate = State(initialValue: e.endDate)
            _taskDate = State(initialValue: cal.startOfDay(for: e.startDate))
            _tag = State(initialValue: e.tag)
            _project = State(initialValue: e.project)
            _taskStatus = State(initialValue: e.task)
            _notes = State(initialValue: e.notes)
            _isTask = State(initialValue: e.isTask)
            _parentID = State(initialValue: e.parentID)
            
            if let r = e.recurrence, r.isEnabled {
                _recurrenceEnabled = State(initialValue: true)
                _recurrenceFrequency = State(initialValue: r.frequency)
                _recurrenceInterval = State(initialValue: r.interval)
                _recurrenceUntil = State(initialValue: r.until)
                _weeklyDays = State(initialValue: r.weekdays)
            }
        } else {
            let base = initialDate ?? Date()
            let hour = initialHour ?? cal.component(.hour, from: Date())
            let s = cal.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
            let e = cal.date(byAdding: .hour, value: 1, to: s) ?? s
            _startDate = State(initialValue: s)
            _endDate = State(initialValue: e)
            _taskDate = State(initialValue: cal.startOfDay(for: base))
            _isTask = State(initialValue: false)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Üst switch: Görev / Etkinlik (Week/Day görünümü gibi)
                Section {
                    HStack {
                        Spacer()
                        TaskEventSwitch(isTask: $isTask)
                        Spacer()
                    }
                    // Hücre zemini şeffaf → sadece kapsülün arkası cam görünsün
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                
                // Başlık + durum (görevse)
                Section("Görev Bilgileri") {
                    TextField("Başlık", text: $title)
                    
                    if isTask {
                        Picker("Durum", selection: $taskStatus) {
                            ForEach(taskOptions, id: \.self) { Text($0).tag($0) }
                        }
                    }
                }
                
                // Tarih
                Section("Tarih") {
                    if isTask {
                        // SAAT YOK — sadece tarih
                        DatePicker("Tarih", selection: $taskDate, displayedComponents: [.date])
                    } else {
                        DatePicker("Başlangıç", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("Bitiş", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                // Kategoriler + bağlantılı görev (hemen burada)
                Section("Kategoriler") {
                    Picker("Tag", selection: $tag) {
                        Text("— Seç —").tag("")
                        ForEach(allTags, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Proje", selection: $project) {
                        Text("— Seç —").tag("")
                        ForEach(allProjects, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Bağlantılı Görev (Üst)", selection: $parentID) {
                        Text("— Yok —").tag(nil as UUID?)
                        ForEach(linkableParentTasks, id: \.id) { e in
                            Text(e.title).tag(Optional(e.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(tag.isEmpty && project.isEmpty)
                }
                
                // Tekrarlama (Toggle eski yerine döndü)
                Section("Tekrarlama") {
                    Toggle("Tekrarlı", isOn: $recurrenceEnabled)
                        .onChange(of: recurrenceEnabled) { _, on in
                            if on && recurrenceFrequency == .none { recurrenceFrequency = .daily }
                            if !on { recurrenceFrequency = .none }
                        }
                    
                    if recurrenceEnabled {
                        Picker("Sıklık", selection: $recurrenceFrequency) {
                            Text("Günlük").tag(RecurrenceRule.Frequency.daily)
                            Text("Haftalık").tag(RecurrenceRule.Frequency.weekly)
                            Text("Aylık").tag(RecurrenceRule.Frequency.monthly)
                        }
                        .pickerStyle(.segmented)
                        
                        Stepper(value: $recurrenceInterval, in: 1...30) {
                            Text("Her \(recurrenceInterval) \(labelFor(recurrenceFrequency))")
                        }
                        
                        if recurrenceFrequency == .weekly {
                            WeekdayChooser(selected: $weeklyDays)
                        }
                        
                        DatePicker("Bitiş (opsiyonel)", selection: Binding(
                            get: { recurrenceUntil ?? Date() },
                            set: { recurrenceUntil = $0 }
                        ), displayedComponents: [.date])
                        .opacity(recurrenceUntil == nil ? 0.6 : 1)
                        .overlay(alignment: .trailing) {
                            if recurrenceUntil != nil {
                                Button { recurrenceUntil = nil } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                }
                                .padding(.trailing, 6)
                            }
                        }
                    }
                }
                
                // Alt panel: Notlar / Bağlantılı / Pomodoro — sınırlandırılmış genişlik
                Section {
                    HStack {
                        Spacer()
                        detailSwitchLimited
                        Spacer()
                    }
                    // Hücre zemini şeffaf → sadece kapsülün arkası cam görünsün
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    
                    Group {
                        switch detailTab {
                        case .notes:
                            TextEditor(text: $notes)
                                .frame(minHeight: 100)
                            
                        case .subtasks:
                            if let editing = editingEvent {
                                let children = childTasks(of: editing.id)
                                if children.isEmpty {
                                    Text("Bu görevin alt görevi yok.")
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(children, id: \.id) { c in
                                        HStack {
                                            Image(systemName: "arrow.turn.down.right")
                                            Text(c.title)
                                            Spacer()
                                            Text(c.task).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                }
                            } else {
                                Text("Alt görevler, kaydettikten sonra burada görünür.")
                                    .foregroundColor(.secondary)
                            }
                            
                        case .pomodoro:
                            if let editing = editingEvent, let provider = pomodoroProvider {
                                let sessions = provider(editing.id)
                                if sessions.isEmpty {
                                    Text("Bu göreve bağlı pomodoro oturumu yok.")
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(sessions, id: \.id) { s in
                                        HStack {
                                            Circle().frame(width: 6, height: 6)
                                            Text(s.start.formatted(date: .abbreviated, time: .shortened))
                                            Spacer()
                                            Text("\(s.durationMinutes) dk").foregroundColor(.secondary)
                                        }
                                    }
                                }
                            } else {
                                Text("Pomodoro geçmişi yok.").foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                
                // Sil
                if let e = editingEvent {
                    Section {
                        Button(role: .destructive) { deleteEvent(e) } label: {
                            HStack { Spacer(); Text("Sil"); Spacer() }
                        }
                    }
                }
            }
            .navigationTitle(editingEvent == nil ? "Yeni Görev/Etkinlik" : "Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") { saveEvent() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var linkableParentTasks: [PlannerEvent] {
        let currentID = editingEvent?.id
        return allEvents
            .filter { e in e.isTask && e.tag == tag && e.project == project && e.id != currentID }
            .sorted { $0.title < $1.title }
    }
    
    private func childTasks(of parent: UUID) -> [PlannerEvent] {
        allEvents.filter { $0.parentID == parent }.sorted { $0.title < $1.title }
    }
    
    private func labelFor(_ f: RecurrenceRule.Frequency) -> String {
        switch f {
        case .daily: return "gün"
        case .weekly: return "hafta"
        case .monthly: return "ay"
        case .none: return ""
        }
    }
    
    private func deleteEvent(_ e: PlannerEvent) {
        onDelete?(e)
        isPresented = false
    }
    
    private func saveEvent() {
        let cal = Calendar.current
        
        // Görevse: saat yok → günü işaretle (start=end=günün başlangıcı)
        let start = isTask ? cal.startOfDay(for: taskDate) : startDate
        let end   = isTask ? cal.startOfDay(for: taskDate) : max(endDate, startDate)
        
        let recurrence: RecurrenceRule? = recurrenceEnabled
        ? RecurrenceRule(
            frequency: recurrenceFrequency,
            interval: recurrenceInterval,
            weekdays: recurrenceFrequency == .weekly ? weeklyDays : [],
            until: recurrenceUntil
        )
        : nil
        
        let newEvent = PlannerEvent(
            id: editingEvent?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: start,
            endDate: end,
            color: editingEvent?.color ?? "blue",
            notes: notes,
            tag: tag,
            project: project,
            task: isTask ? taskStatus : (editingEvent?.task ?? "To Do"),
            parentID: parentID,
            recurrence: recurrence,
            pomodoroSessions: editingEvent?.pomodoroSessions ?? []
        )
        onSave?(newEvent)
        isPresented = false
    }
    
    // MARK: - UI parçaları
    
    // Görev / Etkinlik switch (Week/Day’e benzer)
    private struct TaskEventSwitch: View {
        @Binding var isTask: Bool
        private let height: CGFloat = 36
        private let spacing: CGFloat = 6
        
        var body: some View {
            HStack(spacing: spacing) {
                pill("Görev", isOn: isTask) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isTask = true }
                }
                pill("Etkinlik", isOn: !isTask) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isTask = false }
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
    
    // Notlar / Bağlantılı / Pomodoro — genişlik sınırlı switch
    private var detailSwitchLimited: some View {
        HStack(spacing: 6) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    detailTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(detailTab == tab ? .blue : .primary.opacity(0.75))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(detailTab == tab ? Capsule().fill(Color.blue.opacity(0.14)) : nil)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: 360)                 // <-- sınırlandırıldı
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

// Haftalık gün seçici (Pzt–Paz)
private struct WeekdayChooser: View {
    @Binding var selected: Set<Int>
    private let days: [(Int, String)] = [(2,"Pzt"),(3,"Sal"),(4,"Çar"),(5,"Per"),(6,"Cum"),(7,"Cmt"),(1,"Paz")]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.0) { (value, label) in
                let on = selected.contains(value)
                Button {
                    if on { selected.remove(value) } else { selected.insert(value) }
                } label: {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(on ? Color.blue.opacity(0.14) : Color.clear)
                        .foregroundColor(on ? .blue : .primary.opacity(0.75))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
