
import SwiftUI
import Combine

// MARK: - Models

enum PomodoroMode: String, Codable, CaseIterable, Identifiable {
    case focus = "Odak"
    case breakTime = "Mola"
    var id: String { rawValue }
}

struct PomodoroSessionLog: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var start: Date = Date()
    var end: Date? = nil
    var mode: PomodoroMode = .focus
    var durationSeconds: Int = 0
    var eventID: UUID? = nil
    var notes: String = ""
    var wasCompleted: Bool = false
}

// MARK: - View

struct PomodoroView: View {
    @EnvironmentObject private var dataStore: DataStore

    @State private var events: [PlannerEvent] = []

    var onBackup: (() -> Void)? = nil
    var onRefresh: (() -> Void)? = nil
    
    @State private var currentMode: PomodoroMode = .focus
    
    // Süre yönetimi
    @State private var elapsed: Int = 0
    @State private var customTotalSeconds: Int? = nil
    private var baseSeconds: Int { currentMode == .focus ? 25*60 : 5*60 }
    private var totalSeconds: Int { customTotalSeconds ?? baseSeconds }
    private var remaining: Int { max(totalSeconds - elapsed, 0) }
    private var progress: CGFloat { totalSeconds == 0 ? 0 : CGFloat(elapsed) / CGFloat(totalSeconds) }
    
    // Inline zaman düzenleme
    @State private var isEditingTime = false
    @State private var minuteInput: String = ""
    @State private var secondInput: String = ""
    @FocusState private var focusMinuteField: Bool
    @FocusState private var focusSecondField: Bool
    
    // Zamanlayıcı
    @State private var isRunning = false
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Görev seçimi
    @State private var activeEventID: UUID? = nil
    @State private var showTaskPicker = false
    
    // Geçmiş
    @State private var history: [PomodoroSessionLog] = []
    @State private var showHistory = false
    @State private var pendingNote: String = ""
    private let pendingNoteKey = "PomodoroView_PendingNote"
    
    // Filtreler
    @State private var selectedTag: String? = nil
    @State private var selectedProject: String? = nil
    
    // Tag/Project management
    @State private var customTags: [String] = []
    @State private var customProjects: [String] = []
    @State private var projectTagMap: [String: String] = [:]
    
    private let controlSize: CGFloat = 34
    private let smallControlSize: CGFloat = 30
    private var surface: Color { Color(UIColor.secondarySystemBackground) }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                toolbarView
                Divider()
                
                // Timer tam ortada
                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 0) {
                            Spacer()
                                .frame(height: max(0, (geo.size.height - 400) / 2))
                            
                            timerBlock
                            
                            controls
                                .padding(.top, 32)
                            
                            Spacer()
                                .frame(height: max(0, (geo.size.height - 400) / 2))
                        }
                        .frame(minHeight: geo.size.height)
                    }
                }
            }
        }
        .onAppear {
            loadEvents()
            loadHistory()
            loadPendingNote()
            resetTimerForCurrentMode()
        }
        .onChange(of: dataStore.tasks) { _ in
            loadEvents()
        }
        .onChange(of: dataStore.pomodoroSessions) { _ in
            loadHistory()
        }
        .onChange(of: currentMode) { _ in
            if customTotalSeconds == nil { resetTimerForCurrentMode() }
        }
        .onReceive(tick) { _ in
            guard isRunning else { return }
            guard elapsed < totalSeconds else { completeSession() ; return }
            elapsed += 1
        }
        .sheet(isPresented: $showTaskPicker) { TaskPickerSheet }
        .sheet(isPresented: $showHistory) { HistorySheet }
    }
    
    // MARK: - Toolbar
    private var toolbarView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Text("Pomodoro")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(minWidth: 100, alignment: .leading)
                
                Spacer()
                
                HStack(spacing: 8) {
                    squareButton(systemName: "square.grid.2x2") { showTaskPicker = true }
                    squareButton(systemName: "arrow.clockwise") { onRefresh?() }
                    squareButton(systemName: "square.and.arrow.up") { onBackup?() }
                }
                .frame(minWidth: 100, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            
            HStack(spacing: 8) {
                FocusBreakSwitch(currentMode: $currentMode)
                Spacer()
                squareButton(systemName: "clock.arrow.circlepath") { showHistory = true }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .padding(.top, 8)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Timer
    private var timerBlock: some View {
        VStack(spacing: 16) {
            ZStack {
                // Arka plan çember
                Circle()
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 16)
                    .frame(width: 240, height: 240)
                
                // Progress çember (içeride kalacak)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .foregroundColor(Color.blue.opacity(0.85))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 228, height: 228)
                    .animation(.easeInOut(duration: 0.25), value: progress)
                
                VStack(spacing: 8) {
                    if isEditingTime {
                        HStack(spacing: 4) {
                            TextField("00", text: $minuteInput)
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                                .frame(width: 80)
                                .monospacedDigit()
                                .focused($focusMinuteField)
                                .onAppear { focusMinuteField = true }
                            
                            Text(":")
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                            
                            TextField("00", text: $secondInput)
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                                .frame(width: 80)
                                .monospacedDigit()
                                .focused($focusSecondField)
                        }
                        
                        Button("Tamam") { commitTimeChange() }
                            .font(.caption)
                            .padding(.top, 4)
                    } else {
                        Text(timeString(remaining))
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .onTapGesture { beginTimeEditing() }
                        
                        // Seçili görev çemberin içinde
                        if let eventID = activeEventID,
                           let event = events.first(where: { $0.id == eventID }) {
                            Text(event.title)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .frame(width: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Controls
    private var controls: some View {
        HStack(spacing: 10) {
            if isRunning {
                controlButton("Durdur", system: "pause.fill") {
                    isRunning = false
                }
                controlButton("Tamamla", system: "checkmark.circle.fill") {
                    completeSession()
                }
            } else {
                if elapsed > 0 && elapsed < totalSeconds {
                    controlButton("Sürdür", system: "play.fill") {
                        isRunning = true
                    }
                } else {
                    controlButton("Başlat", system: "play.fill") {
                        startTimer()
                    }
                }
                controlButton("Sıfırla", system: "arrow.counterclockwise") {
                    resetTimer()
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helper Views
    
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
    
    private func controlButton(_ title: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: system)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Sheets
    
    private var TaskPickerSheet: some View {
        TaskPickerView(
            events: $events,
            selectedTag: $selectedTag,
            selectedProject: $selectedProject,
            customTags: $customTags,
            customProjects: $customProjects,
            projectTagMap: $projectTagMap,
            activeEventID: $activeEventID,
            showTaskPicker: $showTaskPicker
        )
    }
    
    private var HistorySheet: some View {
        HistoryView(
            history: $history,
            pendingNote: $pendingNote,
            events: events,
            onSave: { saveHistory(); savePendingNote() },
            onDelete: deleteLog,
            titleFormatter: titleFor
        )
    }
    
    // MARK: - Actions
    
    private func beginTimeEditing() {
        isRunning = false
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        minuteInput = String(format: "%02d", mins)
        secondInput = String(format: "%02d", secs)
        isEditingTime = true
    }
    
    private func commitTimeChange() {
        let m = Int(minuteInput) ?? 0
        let s = Int(secondInput) ?? 0
        let total = max(1, m * 60 + min(59, max(0, s)))
        customTotalSeconds = total
        elapsed = 0
        isEditingTime = false
        focusMinuteField = false
        focusSecondField = false
    }
    
    private func startTimer() {
        if elapsed >= totalSeconds { elapsed = 0 }
        isRunning = true
    }
    
    private func resetTimer() {
        isRunning = false
        elapsed = 0
        customTotalSeconds = nil
        activeEventID = nil
    }
    
    private func completeSession() {
        isRunning = false
        let secs = min(elapsed, totalSeconds)
        let log = PomodoroSessionLog(
            start: Date().addingTimeInterval(TimeInterval(-secs)),
            end: Date(),
            mode: currentMode,
            durationSeconds: secs,
            eventID: activeEventID,
            notes: pendingNote.trimmingCharacters(in: .whitespacesAndNewlines),
            wasCompleted: true
        )
        dataStore.addPomodoroSession(log)
        pendingNote = ""
        savePendingNote()
        elapsed = 0
    }
    
    private func deleteLog(_ log: PomodoroSessionLog) {
        dataStore.deletePomodoroSession(log)
    }
    
    // MARK: - Data

    private func loadEvents() {
        events = dataStore.getPlannerEvents()
    }

    private func loadHistory() {
        history = dataStore.getPomodoroSessionLogs()
    }

    private func saveHistory() {
        // No longer needed - DataStore handles persistence
    }
    
    private func loadPendingNote() {
        pendingNote = UserDefaults.standard.string(forKey: pendingNoteKey) ?? ""
    }
    
    private func savePendingNote() {
        UserDefaults.standard.set(pendingNote, forKey: pendingNoteKey)
    }
    
    private func resetTimerForCurrentMode() {
        elapsed = 0
    }
    
    // MARK: - Formatters
    
    private func timeString(_ secs: Int) -> String {
        let m = max(0, secs) / 60, s = max(0, secs) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private func titleFor(_ log: PomodoroSessionLog) -> String {
        if let id = log.eventID, let e = events.first(where: { $0.id == id }) {
            return e.title
        }
        return log.mode.rawValue
    }
}

// MARK: - Task Picker View

struct TaskPickerView: View {
    @EnvironmentObject private var dataStore: DataStore

    @Binding var events: [PlannerEvent]
    @Binding var selectedTag: String?
    @Binding var selectedProject: String?
    @Binding var customTags: [String]
    @Binding var customProjects: [String]
    @Binding var projectTagMap: [String: String]
    @Binding var activeEventID: UUID?
    @Binding var showTaskPicker: Bool

    @State private var showingEventForm = false
    
    private enum Popup { case tagAdd, tagEdit, projectAdd, projectEdit }
    @State private var activePopup: Popup? = nil
    @State private var tagNameField: String = ""
    @State private var projectNameField: String = ""
    @State private var chosenTagForProject: String = ""
    
    private let smallControlSize: CGFloat = 30
    private var surface: Color { Color(UIColor.secondarySystemBackground) }
    
    private var allTags: [String] {
        let tags = events.map { $0.tag }.filter { !$0.isEmpty }
        return Array(Set(tags).union(customTags)).sorted()
    }
    
    private var allProjects: [String] {
        let ps = events.map { $0.project }.filter { !$0.isEmpty }
        return Array(Set(ps).union(customProjects)).sorted()
    }
    
    private var projectsForSelectedTag: [String] {
        guard let t = selectedTag, !t.isEmpty else { return allProjects }
        let fromEvents = events.filter { normalize($0.tag) == normalize(t) && !$0.project.isEmpty }.map { $0.project }
        let fromMap = projectTagMap.compactMap { normalize($0.value) == normalize(t) ? $0.key : nil }
        return Array(Set(fromEvents).union(fromMap)).sorted()
    }
    
    private var filteredEventChoices: [PlannerEvent] {
        events.filter { e in
            var ok = true
            if let t = selectedTag, !t.isEmpty { ok = ok && normalize(e.tag) == normalize(t) }
            if let p = selectedProject, !p.isEmpty { ok = ok && normalize(e.project) == normalize(p) }
            return ok
        }.sorted { $0.title < $1.title }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Text("Görev")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                    smallSquareButton(systemName: "plus") {
                        showingEventForm = true
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
                .background(Color(UIColor.systemBackground))
                
                // Filter bar
                HStack(spacing: 10) {
                    smallSquareButton(systemName: "plus", tint: .blue) {
                        if let t = selectedTag, !t.isEmpty {
                            tagNameField = t
                            activePopup = .tagEdit
                        } else {
                            tagNameField = ""
                            activePopup = .tagAdd
                        }
                    }
                    
                    Menu {
                        Button("Tümü") { selectedTag = nil; selectedProject = nil }
                        ForEach(allTags, id: \.self) { tag in
                            Button(tag) { selectedTag = tag; selectedProject = nil }
                        }
                    } label: {
                        filterChip(title: "Tag", value: selectedTag ?? "Tümü", color: .blue)
                    }
                    
                    Menu {
                        Button("Tümü") { selectedProject = nil }
                        ForEach(projectsForSelectedTag, id: \.self) { p in
                            Button(p) { selectedProject = p }
                        }
                    } label: {
                        filterChip(title: "Project", value: selectedProject ?? "Tümü", color: .green)
                    }
                    
                    smallSquareButton(systemName: "plus", tint: .green) {
                        if let p = selectedProject, !p.isEmpty {
                            projectNameField = p
                            chosenTagForProject = projectTagMap[p] ?? (selectedTag ?? allTags.first ?? "")
                            activePopup = .projectEdit
                        } else {
                            projectNameField = ""
                            chosenTagForProject = selectedTag ?? allTags.first ?? ""
                            activePopup = .projectAdd
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))
                
                Divider()
                
                // Liste (Basit görünüm)
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredEventChoices, id: \.id) { event in
                            simpleTaskCard(event: event)
                                .onTapGesture {
                                    activeEventID = event.id
                                    showTaskPicker = false
                                }
                        }
                    }
                    .padding(16)
                }
            }
            
            // Popups
            if let popup = activePopup {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { dismissPopup() }
                
                switch popup {
                case .tagAdd:
                    ModernTagPopup(
                        title: "Yeni Tag",
                        name: $tagNameField,
                        showDelete: false,
                        onSave: saveNewTag,
                        onDelete: nil,
                        onCancel: dismissPopup
                    )
                    
                case .tagEdit:
                    ModernTagPopup(
                        title: "Tag Düzenle",
                        name: $tagNameField,
                        showDelete: true,
                        onSave: saveEditedTag,
                        onDelete: deleteCurrentTag,
                        onCancel: dismissPopup
                    )
                    
                case .projectAdd:
                    ModernProjectPopup(
                        title: "Yeni Proje",
                        name: $projectNameField,
                        selectedTag: $chosenTagForProject,
                        tags: allTags,
                        showDelete: false,
                        onSave: saveNewProject,
                        onDelete: nil,
                        onCancel: dismissPopup
                    )
                    
                case .projectEdit:
                    ModernProjectPopup(
                        title: "Proje Düzenle",
                        name: $projectNameField,
                        selectedTag: $chosenTagForProject,
                        tags: allTags,
                        showDelete: true,
                        onSave: saveEditedProject,
                        onDelete: deleteCurrentProject,
                        onCancel: dismissPopup
                    )
                }
            }
        }
        .sheet(isPresented: $showingEventForm) {
            EventFormView(
                isPresented: $showingEventForm,
                allEvents: events,
                allTags: allTags,
                allProjects: allProjects,
                pomodoroProvider: { eventID in
                    dataStore.pomodoroSessions
                        .filter { $0.task?.id == eventID }
                        .map { $0.toPomodoroSession() }
                },
                onSave: { newEvent in
                    dataStore.addTask(newEvent)
                    // Refresh local events array
                    events = dataStore.getPlannerEvents()
                }
            )
        }
    }
    
    // MARK: - Simple Task Card
    private func simpleTaskCard(event: PlannerEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Metadata tek satırda
            HStack(spacing: 4) {
                if !event.tag.isEmpty {
                    Text(event.tag)
                        .font(.caption2)
                }
                if !event.project.isEmpty {
                    if !event.tag.isEmpty {
                        Text("•").font(.caption2)
                    }
                    Text(event.project)
                        .font(.caption2)
                }
                if let pid = event.parentID,
                   let parent = events.first(where: { $0.id == pid }) {
                    if !event.tag.isEmpty || !event.project.isEmpty {
                        Text("•").font(.caption2)
                    }
                    Text(parent.title)
                        .font(.caption2)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(event.endDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(activeEventID == event.id ? Color.blue.opacity(0.3) : Color.white.opacity(0.06), lineWidth: activeEventID == event.id ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 5, y: 3)
    }
    
    private func smallSquareButton(systemName: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor((tint ?? .primary).opacity(0.9))
                .frame(width: smallControlSize, height: smallControlSize)
                .background(
                    ZStack {
                        if let tint { tint.opacity(0.12) }
                        Color.clear.background(.ultraThinMaterial)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    private func filterChip(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text("\(title): \(value)")
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .frame(height: 30)
        .padding(.horizontal, 10)
        .background(color.opacity(0.10), in: Capsule())
        .foregroundColor(color)
    }
    
    // Tag/Project ops
    private func saveNewTag() {
        let name = tagNameField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if !customTags.contains(where: { normalize($0) == normalize(name) }) { customTags.append(name) }
        selectedTag = name
        selectedProject = nil
        dismissPopup()
    }
    
    private func saveEditedTag() {
        guard let old = selectedTag else { return }
        let new = tagNameField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !new.isEmpty else { return }
        for i in events.indices where normalize(events[i].tag) == normalize(old) { events[i].tag = new }
        if let idx = customTags.firstIndex(where: { normalize($0) == normalize(old) }) { customTags[idx] = new }
        for (k, v) in projectTagMap where normalize(v) == normalize(old) { projectTagMap[k] = new }
        selectedTag = new
        dismissPopup()
    }
    
    private func deleteCurrentTag() {
        guard let name = selectedTag else { return }
        for i in events.indices where normalize(events[i].tag) == normalize(name) { events[i].tag = "" }
        customTags.removeAll { normalize($0) == normalize(name) }
        for (k, v) in projectTagMap where normalize(v) == normalize(name) { projectTagMap[k] = "" }
        selectedTag = nil
        selectedProject = nil
        dismissPopup()
    }
    
    private func saveNewProject() {
        let name = projectNameField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if !customProjects.contains(where: { normalize($0) == normalize(name) }) { customProjects.append(name) }
        if !chosenTagForProject.isEmpty { projectTagMap[name] = chosenTagForProject }
        selectedProject = name
        dismissPopup()
    }
    
    private func saveEditedProject() {
        guard let old = selectedProject else { return }
        let new = projectNameField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !new.isEmpty else { return }
        for i in events.indices where normalize(events[i].project) == normalize(old) { events[i].project = new }
        if let idx = customProjects.firstIndex(where: { normalize($0) == normalize(old) }) { customProjects[idx] = new }
        else if !customProjects.contains(where: { normalize($0) == normalize(new) }) { customProjects.append(new) }
        projectTagMap[new] = chosenTagForProject
        projectTagMap.removeValue(forKey: old)
        selectedProject = new
        dismissPopup()
    }
    
    private func deleteCurrentProject() {
        guard let name = selectedProject else { return }
        for i in events.indices where normalize(events[i].project) == normalize(name) { events[i].project = "" }
        customProjects.removeAll { normalize($0) == normalize(name) }
        projectTagMap.removeValue(forKey: name)
        selectedProject = nil
        dismissPopup()
    }
    
    private func dismissPopup() { activePopup = nil }
    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Locale.current)
    }
}

// MARK: - History View

struct HistoryView: View {
    @EnvironmentObject private var dataStore: DataStore

    @Binding var history: [PomodoroSessionLog]
    @Binding var pendingNote: String
    let events: [PlannerEvent]
    let onSave: () -> Void
    let onDelete: (PomodoroSessionLog) -> Void
    let titleFormatter: (PomodoroSessionLog) -> String
    
    @State private var editingLog: PomodoroSessionLog?
    @State private var editNoteText: String = ""
    
    private var surface: Color { Color(UIColor.secondarySystemBackground) }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("Geçmiş")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .background(Color(UIColor.systemBackground))
            
            Divider()
            
            // Liste
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(history.sorted(by: { ($0.end ?? $0.start) > ($1.end ?? $1.start) })) { log in
                        historyRow(log: log)
                            .onTapGesture {
                                editingLog = log
                                editNoteText = log.notes
                            }
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            
            Divider()
            
            // Not alanı
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Oturum Notu")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let log = editingLog {
                        Text(titleFormatter(log))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Yeni Oturum")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                TextEditor(text: editingLog == nil ? $pendingNote : $editNoteText)
                    .frame(height: 100)
                    .padding(8)
                    .background(surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.1), lineWidth: 1))
                
                if editingLog != nil {
                    HStack(spacing: 10) {
                        Button(action: deleteCurrentLog) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text("Sil")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.2), lineWidth: 1))
                        }
                        
                        Button(action: saveNote) {
                            Text("Kaydet")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                } else {
                    Button(action: savePendingNote) {
                        Text("Kaydet")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .padding(16)
            .background(Color(UIColor.systemBackground))
        }
    }
    
    private func historyRow(log: PomodoroSessionLog) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: log.mode == .focus ? "timer" : "cup.and.saucer")
                .foregroundColor(.blue)
                .font(.system(size: 20))
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(titleFormatter(log))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(dateString(for: (log.end ?? log.start)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeString(log.durationSeconds))
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
                
                if log.wasCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(editingLog?.id == log.id ? Color.blue.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
    }
    
    private func saveNote() {
        guard var log = editingLog else { return }
        log.notes = editNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        dataStore.updatePomodoroSession(log)
        editingLog = nil
        editNoteText = ""
    }
    
    private func savePendingNote() {
        onSave()
    }
    
    private func deleteCurrentLog() {
        guard let log = editingLog else { return }
        onDelete(log)
        editingLog = nil
        editNoteText = ""
    }
    
    private func timeString(_ secs: Int) -> String {
        let m = max(0, secs) / 60, s = max(0, secs) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private func dateString(for date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}

// MARK: - Modern Popups (Renkler kaldırıldı)

struct ModernTagPopup: View {
    let title: String
    @Binding var name: String
    let showDelete: Bool
    let onSave: () -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            
            Divider()
            
            // Content
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tag Adı")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    TextField("Örn: Önemli, Acil, İş...", text: $name)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // Buttons
                HStack(spacing: 12) {
                    if showDelete, let onDelete {
                        Button(action: onDelete) {
                            Text("Sil")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    
                    Button(action: onSave) {
                        Text("Kaydet")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: 400)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 15)
        .padding(.horizontal, 24)
    }
}

struct ModernProjectPopup: View {
    let title: String
    @Binding var name: String
    @Binding var selectedTag: String
    let tags: [String]
    let showDelete: Bool
    let onSave: () -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            
            Divider()
            
            // Content
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Proje Adı")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    TextField("Örn: iOS App, Website, Tasarım...", text: $name)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("İlişkili Tag")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(tags, id: \.self) { tag in
                            Button(tag) { selectedTag = tag }
                        }
                    } label: {
                        HStack {
                            Text(selectedTag.isEmpty ? "Tag Seç" : selectedTag)
                                .foregroundColor(selectedTag.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                
                // Buttons
                HStack(spacing: 12) {
                    if showDelete, let onDelete {
                        Button(action: onDelete) {
                            Text("Sil")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    
                    Button(action: onSave) {
                        Text("Kaydet")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: 400)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 15)
        .padding(.horizontal, 24)
    }
}

// MARK: - Switch

struct FocusBreakSwitch: View {
    @Binding var currentMode: PomodoroMode
    
    private let height: CGFloat = 36
    private let spacing: CGFloat = 6
    
    var body: some View {
        HStack(spacing: spacing) {
            pill("Odak", isOn: currentMode == .focus) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    currentMode = .focus
                }
            }
            pill("Mola", isOn: currentMode == .breakTime) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    currentMode = .breakTime
                }
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
