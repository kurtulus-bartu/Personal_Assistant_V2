// DataStore.swift
import Foundation
import SwiftUI
import SwiftData

/// SwiftData model for PlannerEvent
@Model
final class TaskItem {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var color: String
    var notes: String
    var tag: String
    var project: String
    var task: String

    // Optional fields
    var assignee: String?
    var parentID: UUID?

    // Recurrence
    var recurrenceFrequency: String? // "none", "daily", "weekly", "monthly"
    var recurrenceInterval: Int
    var recurrenceWeekdays: [Int] // Calendar weekdays: 1=Sunday, ..., 7=Saturday
    var recurrenceUntil: Date?

    // Relationship to pomodoro sessions
    @Relationship(deleteRule: .cascade, inverse: \PomodoroItem.task)
    var pomodoroSessions: [PomodoroItem] = []

    // Computed properties
    var isTask: Bool { startDate == endDate }

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        color: String = "blue",
        notes: String = "",
        tag: String = "",
        project: String = "",
        task: String = "To Do",
        assignee: String? = nil,
        parentID: UUID? = nil,
        recurrenceFrequency: String? = nil,
        recurrenceInterval: Int = 1,
        recurrenceWeekdays: [Int] = [],
        recurrenceUntil: Date? = nil
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
        self.recurrenceFrequency = recurrenceFrequency
        self.recurrenceInterval = recurrenceInterval
        self.recurrenceWeekdays = recurrenceWeekdays
        self.recurrenceUntil = recurrenceUntil
    }

    // Convert from PlannerEvent
    static func from(_ event: PlannerEvent) -> TaskItem {
        TaskItem(
            id: event.id,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            color: event.color,
            notes: event.notes,
            tag: event.tag,
            project: event.project,
            task: event.task,
            assignee: event.assignee,
            parentID: event.parentID,
            recurrenceFrequency: event.recurrence?.frequency.rawValue,
            recurrenceInterval: event.recurrence?.interval ?? 1,
            recurrenceWeekdays: event.recurrence?.weekdays.sorted() ?? [],
            recurrenceUntil: event.recurrence?.until
        )
    }

    // Convert to PlannerEvent
    func toPlannerEvent() -> PlannerEvent {
        var recurrence: RecurrenceRule? = nil
        if let freq = recurrenceFrequency, let frequency = RecurrenceRule.Frequency(rawValue: freq) {
            recurrence = RecurrenceRule(
                frequency: frequency,
                interval: recurrenceInterval,
                weekdays: Set(recurrenceWeekdays),
                until: recurrenceUntil
            )
        }

        return PlannerEvent(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            color: color,
            notes: notes,
            tag: tag,
            project: project,
            task: task,
            assignee: assignee,
            parentID: parentID,
            recurrence: recurrence,
            pomodoroSessions: pomodoroSessions.map { $0.toPomodoroSession() }
        )
    }
}

/// SwiftData model for Note
@Model
final class NoteItem {
    var id: UUID
    var date: Date
    var title: String
    var content: String
    var tags: [String]
    var project: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        title: String = "",
        content: String = "",
        tags: [String] = [],
        project: String = ""
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.content = content
        self.tags = tags
        self.project = project
    }

    // Convert from Note
    static func from(_ note: Note) -> NoteItem {
        NoteItem(
            id: note.id,
            date: note.date,
            title: note.title,
            content: note.content,
            tags: note.tags,
            project: note.project
        )
    }

    // Convert to Note
    func toNote() -> Note {
        Note(
            id: id,
            date: date,
            title: title,
            content: content,
            tags: tags,
            project: project
        )
    }
}

/// SwiftData model for Pomodoro Session
@Model
final class PomodoroItem {
    var id: UUID
    var start: Date
    var end: Date?
    var mode: String // "focus" or "break"
    var durationSeconds: Int
    var notes: String
    var wasCompleted: Bool

    // Relationship to task
    var task: TaskItem?

    init(
        id: UUID = UUID(),
        start: Date = Date(),
        end: Date? = nil,
        mode: String = "focus",
        durationSeconds: Int = 0,
        notes: String = "",
        wasCompleted: Bool = false,
        task: TaskItem? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.mode = mode
        self.durationSeconds = durationSeconds
        self.notes = notes
        self.wasCompleted = wasCompleted
        self.task = task
    }

    // Convert to PomodoroSession
    func toPomodoroSession() -> PomodoroSession {
        PomodoroSession(
            id: id,
            start: start,
            durationMinutes: durationSeconds / 60,
            completed: wasCompleted
        )
    }

    // Convert to PomodoroSessionLog
    func toPomodoroSessionLog() -> PomodoroSessionLog {
        let pomodoroMode: PomodoroMode = mode == "focus" ? .focus : .breakTime
        return PomodoroSessionLog(
            id: id,
            start: start,
            end: end,
            mode: pomodoroMode,
            durationSeconds: durationSeconds,
            eventID: task?.id,
            notes: notes,
            wasCompleted: wasCompleted
        )
    }

    // Convert from PomodoroSessionLog
    static func from(_ log: PomodoroSessionLog, task: TaskItem? = nil) -> PomodoroItem {
        PomodoroItem(
            id: log.id,
            start: log.start,
            end: log.end,
            mode: log.mode == .focus ? "focus" : "break",
            durationSeconds: log.durationSeconds,
            notes: log.notes,
            wasCompleted: log.wasCompleted,
            task: task
        )
    }
}

/// ObservableObject wrapper for SwiftData operations
@MainActor
class DataStore: ObservableObject {
    let modelContainer: ModelContainer
    private let modelContext: ModelContext

    @Published var tasks: [TaskItem] = []
    @Published var pomodoroSessions: [PomodoroItem] = []
    @Published var notes: [NoteItem] = []

    /// Clean up corrupted database files
    static func cleanupDatabase() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("Could not locate application support directory")
            return
        }

        // SwiftData typically stores files in a "default.store" file
        let storeURL = appSupport.appendingPathComponent("default.store")
        let storeSHMURL = appSupport.appendingPathComponent("default.store-shm")
        let storeWALURL = appSupport.appendingPathComponent("default.store-wal")

        for url in [storeURL, storeSHMURL, storeWALURL] {
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                    print("🗑️ Removed corrupted database file: \(url.lastPathComponent)")
                } catch {
                    print("⚠️ Failed to remove \(url.lastPathComponent): \(error)")
                }
            }
        }
    }

    init() {
        let schema = Schema([TaskItem.self, PomodoroItem.self, NoteItem.self])

        // Try to create persistent storage first, fall back to in-memory if needed
        let container: ModelContainer
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [configuration])
            print("✅ ModelContainer initialized successfully with persistent storage")
        } catch {
            // If persistent storage fails, try cleaning up and retrying
            print("⚠️ Failed to create persistent ModelContainer: \(error)")
            print("⚠️ Error details: \(String(describing: error))")
            print("🔧 Attempting to clean up corrupted database...")

            DataStore.cleanupDatabase()

            // Try one more time with persistent storage after cleanup
            do {
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                container = try ModelContainer(for: schema, configurations: [configuration])
                print("✅ ModelContainer initialized successfully after cleanup")
            } catch {
                // If still failing, fall back to in-memory storage
                print("⚠️ Still failing after cleanup: \(error)")
                print("⚠️ Falling back to in-memory storage")

                do {
                    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                    container = try ModelContainer(for: schema, configurations: [configuration])
                    print("✅ ModelContainer initialized with in-memory storage")
                } catch {
                    fatalError("Failed to create ModelContainer even with in-memory storage: \(error)")
                }
            }
        }

        // Assign to instance properties
        self.modelContainer = container
        self.modelContext = ModelContext(container)

        // Fetch initial data
        fetchTasks()
        fetchPomodoroSessions()
        fetchNotes()
    }

    // MARK: - Task Operations

    func fetchTasks() {
        let descriptor = FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.startDate)])
        do {
            tasks = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch tasks: \(error)")
        }
    }

    func addTask(_ event: PlannerEvent) {
        let task = TaskItem.from(event)
        modelContext.insert(task)
        saveContext()
        fetchTasks()
    }

    func updateTask(_ event: PlannerEvent) {
        if let task = tasks.first(where: { $0.id == event.id }) {
            task.title = event.title
            task.startDate = event.startDate
            task.endDate = event.endDate
            task.color = event.color
            task.notes = event.notes
            task.tag = event.tag
            task.project = event.project
            task.task = event.task
            task.assignee = event.assignee
            task.parentID = event.parentID

            if let recurrence = event.recurrence {
                task.recurrenceFrequency = recurrence.frequency.rawValue
                task.recurrenceInterval = recurrence.interval
                task.recurrenceWeekdays = recurrence.weekdays.sorted()
                task.recurrenceUntil = recurrence.until
            }

            saveContext()
            fetchTasks()
        }
    }

    func deleteTask(_ event: PlannerEvent) {
        if let task = tasks.first(where: { $0.id == event.id }) {
            modelContext.delete(task)
            saveContext()
            fetchTasks()
        }
    }

    func getTask(by id: UUID) -> TaskItem? {
        tasks.first(where: { $0.id == id })
    }

    // MARK: - Pomodoro Operations

    func fetchPomodoroSessions() {
        let descriptor = FetchDescriptor<PomodoroItem>(sortBy: [SortDescriptor(\.start, order: .reverse)])
        do {
            pomodoroSessions = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch pomodoro sessions: \(error)")
        }
    }

    func addPomodoroSession(_ log: PomodoroSessionLog) {
        let task = log.eventID != nil ? getTask(by: log.eventID!) : nil
        let session = PomodoroItem.from(log, task: task)
        modelContext.insert(session)
        saveContext()
        fetchPomodoroSessions()
    }

    func updatePomodoroSession(_ log: PomodoroSessionLog) {
        if let session = pomodoroSessions.first(where: { $0.id == log.id }) {
            session.start = log.start
            session.end = log.end
            session.mode = log.mode == .focus ? "focus" : "break"
            session.durationSeconds = log.durationSeconds
            session.notes = log.notes
            session.wasCompleted = log.wasCompleted

            if let eventID = log.eventID {
                session.task = getTask(by: eventID)
            }

            saveContext()
            fetchPomodoroSessions()
        }
    }

    func deletePomodoroSession(_ log: PomodoroSessionLog) {
        if let session = pomodoroSessions.first(where: { $0.id == log.id }) {
            modelContext.delete(session)
            saveContext()
            fetchPomodoroSessions()
        }
    }

    // MARK: - Helper Methods

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    // Get PlannerEvents for binding compatibility
    func getPlannerEvents() -> [PlannerEvent] {
        tasks.map { $0.toPlannerEvent() }
    }

    // Get PomodoroSessionLogs for binding compatibility
    func getPomodoroSessionLogs() -> [PomodoroSessionLog] {
        pomodoroSessions.map { $0.toPomodoroSessionLog() }
    }

    // MARK: - Note Operations

    func fetchNotes() {
        let descriptor = FetchDescriptor<NoteItem>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        do {
            notes = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch notes: \(error)")
        }
    }

    func addNote(_ note: Note) {
        let noteItem = NoteItem.from(note)
        modelContext.insert(noteItem)
        saveContext()
        fetchNotes()
    }

    func updateNote(_ note: Note) {
        if let noteItem = notes.first(where: { $0.id == note.id }) {
            noteItem.date = note.date
            noteItem.title = note.title
            noteItem.content = note.content
            noteItem.tags = note.tags
            noteItem.project = note.project
            saveContext()
            fetchNotes()
        }
    }

    func deleteNote(_ note: Note) {
        if let noteItem = notes.first(where: { $0.id == note.id }) {
            modelContext.delete(noteItem)
            saveContext()
            fetchNotes()
        }
    }

    // Get Notes for binding compatibility
    func getNotes() -> [Note] {
        notes.map { $0.toNote() }
    }

    // Migration: Import existing UserDefaults data
    func migrateFromUserDefaults() {
        let historyKey = "PomodoroHistory_v3"
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let logs = try? JSONDecoder().decode([PomodoroSessionLog].self, from: data) {
            for log in logs {
                addPomodoroSession(log)
            }
            // Clear UserDefaults after migration
            UserDefaults.standard.removeObject(forKey: historyKey)
            print("Migrated \(logs.count) pomodoro sessions from UserDefaults")
        }
    }
}
