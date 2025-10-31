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

    init() {
        do {
            let schema = Schema([TaskItem.self, PomodoroItem.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            modelContext = ModelContext(modelContainer)

            fetchTasks()
            fetchPomodoroSessions()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
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
