// NotesView.swift
import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var dataStore: DataStore

    @State private var notes: [Note] = []
    @State private var filteredNotes: [Note] = []

    // Filter states
    @State private var selectedTag: String? = nil
    @State private var selectedProject: String? = nil

    // UI states
    @State private var showAddNote = false
    @State private var showNoteDetail = false
    @State private var selectedNote: Note? = nil

    // New note states
    @State private var newNoteTitle: String = ""
    @State private var newNoteContent: String = ""
    @State private var newNoteTag: String = ""
    @State private var newNoteProject: String = ""

    private let controlSize: CGFloat = 34
    private let smallControlSize: CGFloat = 30

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
                .onTapGesture {
                    hideKeyboard()
                }

            VStack(spacing: 0) {
                toolbarView
                filterView
                Divider()

                ScrollView {
                    VStack(spacing: 16) {
                        if filteredNotes.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(filteredNotes) { note in
                                noteCard(note)
                            }
                        }
                    }
                    .frame(maxWidth: 650)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                }
            }

            // Add Note Sheet
            if showAddNote {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showAddNote = false
                        hideKeyboard()
                    }
                    .zIndex(999)

                addNotePopup
                    .zIndex(1000)
            }

            // Note Detail Sheet
            if showNoteDetail, let note = selectedNote {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showNoteDetail = false
                        selectedNote = nil
                        hideKeyboard()
                    }
                    .zIndex(999)

                noteDetailPopup(note)
                    .zIndex(1000)
            }
        }
        .onAppear {
            loadNotes()
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: 16) {
            Text("Notes")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(minWidth: 100, alignment: .leading)

            Spacer()

            HStack(spacing: 8) {
                squareButton(systemName: "plus") {
                    showAddNote = true
                }
                squareButton(systemName: "arrow.clockwise") {
                    refreshData()
                }
                squareButton(systemName: "square.and.arrow.up") {
                    backupData()
                }
            }
            .frame(minWidth: 100, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Filter View

    private var filterView: some View {
        HStack(spacing: 10) {
            smallSquareButton(systemName: "plus", tint: .blue) {
                // Tag ekleme/düzenleme buradan yapılabilir
            }

            Menu {
                Button("Tümü") { selectedTag = nil; selectedProject = nil }
                ForEach(allTags, id: \.self) { tag in
                    Button(tag) { selectedTag = tag; selectedProject = nil; applyFilters() }
                }
            } label: {
                filterChip(title: "Tag", value: selectedTag ?? "Tümü", color: .blue)
            }

            Menu {
                Button("Tümü") { selectedProject = nil; applyFilters() }
                ForEach(projectsForSelectedTag, id: \.self) { project in
                    Button(project) { selectedProject = project; applyFilters() }
                }
            } label: {
                filterChip(title: "Project", value: selectedProject ?? "Tümü", color: .green)
            }

            smallSquareButton(systemName: "plus", tint: .green) {
                // Proje ekleme/düzenleme buradan yapılabilir
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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

    // MARK: - Note Card

    private func noteCard(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(note.title.isEmpty ? "Başlıksız Not" : note.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Content preview
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Tags and Project
            if !note.tags.isEmpty || !note.project.isEmpty {
                HStack(spacing: 8) {
                    ForEach(note.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .font(.caption2)
                            Text(tag)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())
                    }

                    if !note.project.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                                .font(.caption2)
                            Text(note.project)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
            }

            // Date
            HStack {
                Text(note.date.formatted(.dateTime.month().day().year().hour().minute()))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
        .onTapGesture {
            selectedNote = note
            showNoteDetail = true
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.5))
            Text(selectedTag == nil && selectedProject == nil ? "Henüz not yok" : "Filtre ile eşleşen not bulunamadı")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Yeni bir not eklemek için + butonuna dokunun")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Add Note Popup

    private var addNotePopup: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Yeni Not")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    showAddNote = false
                    resetNewNoteFields()
                    hideKeyboard()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Başlık")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        TextField("Not başlığı", text: $newNoteTitle)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Not İçeriği")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        TextEditor(text: $newNoteContent)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    // Tag
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tag (Opsiyonel)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        tagSelectorForAdd
                    }

                    // Project
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Proje (Opsiyonel)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        projectSelectorForAdd
                    }

                    // Add Button
                    Button(action: addNewNote) {
                        Text("Not Ekle")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(newNoteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(newNoteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
                .padding(20)
            }
            .onTapGesture {
                // ScrollView içinde tap edince hiçbir şey yapma, sadece keyboard'u kapat
                hideKeyboard()
            }
        }
        .frame(maxWidth: 500)
        .frame(maxHeight: 600)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 15)
        .padding(.horizontal, 24)
    }

    // MARK: - Note Detail Popup

    private func noteDetailPopup(_ note: Note) -> some View {
        @State var editedTitle = note.title
        @State var editedContent = note.content
        @State var editedTag = note.tags.first ?? ""
        @State var editedProject = note.project

        return VStack(spacing: 0) {
            // Header
            HStack {
                Text("Not Detayı")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    showNoteDetail = false
                    selectedNote = nil
                    hideKeyboard()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Başlık")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        TextField("Not başlığı", text: $editedTitle)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Not İçeriği")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        TextEditor(text: $editedContent)
                            .frame(minHeight: 200)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    // Tag
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tag")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        tagSelectorForEdit(selectedTag: $editedTag)
                    }

                    // Project
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Proje")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        projectSelectorForEdit(selectedTag: editedTag, selectedProject: $editedProject)
                    }

                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            deleteNote(note)
                            showNoteDetail = false
                            selectedNote = nil
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Sil")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        Button(action: {
                            saveNoteEdit(note, title: editedTitle, content: editedContent, tag: editedTag, project: editedProject)
                            showNoteDetail = false
                            selectedNote = nil
                        }) {
                            Text("Kaydet")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .padding(20)
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
        .frame(maxWidth: 500)
        .frame(maxHeight: 600)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 15)
        .padding(.horizontal, 24)
    }

    // MARK: - Tag Selector for Add

    private var tagSelectorForAdd: some View {
        let availableTags = allTags

        return VStack(alignment: .leading, spacing: 8) {
            if availableTags.isEmpty {
                Text("Henüz tag yok")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Menu {
                    Button("Tag Yok") { newNoteTag = "" }
                    ForEach(availableTags, id: \.self) { tag in
                        Button(tag) { newNoteTag = tag }
                    }
                } label: {
                    HStack {
                        Text(newNoteTag.isEmpty ? "Tag Seç" : newNoteTag)
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .padding(12)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Project Selector for Add

    private var projectSelectorForAdd: some View {
        let availableProjects = projectsForTag(newNoteTag)

        return VStack(alignment: .leading, spacing: 8) {
            if availableProjects.isEmpty {
                Text("Henüz proje yok")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Menu {
                    Button("Proje Yok") { newNoteProject = "" }
                    ForEach(availableProjects, id: \.self) { project in
                        Button(project) { newNoteProject = project }
                    }
                } label: {
                    HStack {
                        Text(newNoteProject.isEmpty ? "Proje Seç" : newNoteProject)
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .padding(12)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Tag Selector for Edit

    private func tagSelectorForEdit(selectedTag: Binding<String>) -> some View {
        let availableTags = allTags

        return VStack(alignment: .leading, spacing: 8) {
            if availableTags.isEmpty {
                Text("Henüz tag yok")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Menu {
                    Button("Tag Yok") { selectedTag.wrappedValue = "" }
                    ForEach(availableTags, id: \.self) { tag in
                        Button(tag) { selectedTag.wrappedValue = tag }
                    }
                } label: {
                    HStack {
                        Text(selectedTag.wrappedValue.isEmpty ? "Tag Seç" : selectedTag.wrappedValue)
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .padding(12)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Project Selector for Edit

    private func projectSelectorForEdit(selectedTag: String, selectedProject: Binding<String>) -> some View {
        let availableProjects = projectsForTag(selectedTag)

        return VStack(alignment: .leading, spacing: 8) {
            if availableProjects.isEmpty {
                Text("Henüz proje yok")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Menu {
                    Button("Proje Yok") { selectedProject.wrappedValue = "" }
                    ForEach(availableProjects, id: \.self) { project in
                        Button(project) { selectedProject.wrappedValue = project }
                    }
                } label: {
                    HStack {
                        Text(selectedProject.wrappedValue.isEmpty ? "Proje Seç" : selectedProject.wrappedValue)
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .padding(12)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
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

    // MARK: - Data Operations

    private func loadNotes() {
        notes = dataStore.getNotes()
        applyFilters()
    }

    private func applyFilters() {
        if selectedTag == nil && selectedProject == nil {
            filteredNotes = notes
        } else {
            filteredNotes = notes.filter { note in
                var match = true
                if let tag = selectedTag {
                    match = match && note.tags.contains(tag)
                }
                if let project = selectedProject {
                    match = match && note.project == project
                }
                return match
            }
        }
    }

    private func addNewNote() {
        guard !newNoteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let note = Note(
            title: newNoteTitle,
            content: newNoteContent,
            tags: newNoteTag.isEmpty ? [] : [newNoteTag],
            project: newNoteProject
        )
        dataStore.addNote(note)
        loadNotes()

        showAddNote = false
        resetNewNoteFields()
        hideKeyboard()
    }

    private func resetNewNoteFields() {
        newNoteTitle = ""
        newNoteContent = ""
        newNoteTag = ""
        newNoteProject = ""
    }

    private func saveNoteEdit(_ note: Note, title: String, content: String, tag: String, project: String) {
        var updatedNote = note
        updatedNote.title = title
        updatedNote.content = content
        updatedNote.tags = tag.isEmpty ? [] : [tag]
        updatedNote.project = project
        dataStore.updateNote(updatedNote)
        loadNotes()
        hideKeyboard()
    }

    private func deleteNote(_ note: Note) {
        dataStore.deleteNote(note)
        loadNotes()
    }

    private func refreshData() {
        loadNotes()
        print("Notes refreshed")
    }

    private func backupData() {
        // Backup işlemi buraya eklenebilir
        print("Notes backed up")
    }

    // MARK: - Helper Functions

    private var allTags: [String] {
        var tags = Set<String>()
        for note in notes {
            tags.formUnion(note.tags)
        }
        // PlannerEvent'lerden de tag'leri al
        for event in dataStore.getPlannerEvents() {
            if !event.tag.isEmpty {
                tags.insert(event.tag)
            }
        }
        return tags.sorted()
    }

    private var projectsForSelectedTag: [String] {
        if let tag = selectedTag {
            return projectsForTag(tag)
        } else {
            return allProjects
        }
    }

    private var allProjects: [String] {
        var projects = Set<String>()
        for note in notes {
            if !note.project.isEmpty {
                projects.insert(note.project)
            }
        }
        // PlannerEvent'lerden de projeleri al
        for event in dataStore.getPlannerEvents() {
            if !event.project.isEmpty {
                projects.insert(event.project)
            }
        }
        return projects.sorted()
    }

    private func projectsForTag(_ tag: String) -> [String] {
        if tag.isEmpty {
            return allProjects
        }

        var projects = Set<String>()

        // Not'lardan ilişkili projeleri al
        for note in notes {
            if note.tags.contains(tag) && !note.project.isEmpty {
                projects.insert(note.project)
            }
        }

        // PlannerEvent'lerden de ilişkili projeleri al
        for event in dataStore.getPlannerEvents() {
            if normalize(event.tag) == normalize(tag) && !event.project.isEmpty {
                projects.insert(event.project)
            }
        }

        return projects.sorted()
    }

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Locale.current)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
