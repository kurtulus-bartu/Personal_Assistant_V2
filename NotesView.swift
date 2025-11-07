// NotesView.swift
import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var dataStore: DataStore

    @State private var notes: [Note] = []
    @State private var filteredNotes: [Note] = []

    // Filter states
    @State private var selectedTags: Set<String> = []
    @State private var selectedProject: String = ""

    // UI states
    @State private var showAddNote = false
    @State private var showFilterPopup = false

    // Edit states
    @State private var editingNoteID: UUID? = nil
    @State private var editingContent: String = ""

    // New note states
    @State private var newNoteContent: String = ""
    @State private var newNoteTags: Set<String> = []
    @State private var newNoteProject: String = ""

    private let controlSize: CGFloat = 34

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                toolbarView
                Divider()

                // Active filters display
                if !selectedTags.isEmpty || !selectedProject.isEmpty {
                    activeFiltersView
                    Divider()
                }

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
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { showAddNote = false }
                    .zIndex(999)

                addNotePopup
                    .zIndex(1000)
            }

            // Filter Popup
            if showFilterPopup {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { showFilterPopup = false }
                    .zIndex(999)

                filterPopup
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
                squareButton(systemName: "line.3.horizontal.decrease.circle") {
                    showFilterPopup = true
                }
                squareButton(systemName: "plus") {
                    showAddNote = true
                }
            }
            .frame(minWidth: 100, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Active Filters View

    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Filtreler:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(Array(selectedTags), id: \.self) { tag in
                    filterChip(text: tag, type: .tag) {
                        selectedTags.remove(tag)
                        applyFilters()
                    }
                }

                if !selectedProject.isEmpty {
                    filterChip(text: selectedProject, type: .project) {
                        selectedProject = ""
                        applyFilters()
                    }
                }

                Button(action: {
                    selectedTags.removeAll()
                    selectedProject = ""
                    applyFilters()
                }) {
                    Text("Temizle")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private enum FilterChipType {
        case tag, project
    }

    private func filterChip(text: String, type: FilterChipType, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Image(systemName: type == .tag ? "tag.fill" : "folder.fill")
                .font(.caption2)
            Text(text)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(type == .tag ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
        .clipShape(Capsule())
    }

    // MARK: - Note Card

    private func noteCard(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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

            // Content
            if editingNoteID == note.id {
                TextEditor(text: $editingContent)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Button("İptal") {
                        editingNoteID = nil
                        editingContent = ""
                    }
                    .foregroundColor(.secondary)

                    Spacer()

                    Button("Kaydet") {
                        saveNoteEdit(note)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                }
            } else {
                Text(note.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture {
                        startEditing(note)
                    }
            }

            // Date and Actions
            HStack {
                Text(note.date.formatted(.dateTime.month().day().year().hour().minute()))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    deleteNote(note)
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.5))
            Text(selectedTags.isEmpty && selectedProject.isEmpty ? "Henüz not yok" : "Filtre ile eşleşen not bulunamadı")
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
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Not İçeriği")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        TextEditor(text: $newNoteContent)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Etiketler (Opsiyonel)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        tagSelector
                    }

                    // Project
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Proje (Opsiyonel)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        projectSelector
                    }

                    // Add Button
                    Button(action: addNewNote) {
                        Text("Not Ekle")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
                .padding(20)
            }
        }
        .frame(maxWidth: 500)
        .frame(maxHeight: 600)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 15)
        .padding(.horizontal, 24)
    }

    // MARK: - Filter Popup

    private var filterPopup: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Filtrele")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showFilterPopup = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Tags
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Etiketler")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        tagSelector
                    }

                    // Project
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Proje")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        projectSelector
                    }

                    // Apply Button
                    Button(action: {
                        applyFilters()
                        showFilterPopup = false
                    }) {
                        Text("Filtrele")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: 400)
        .frame(maxHeight: 500)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 15)
        .padding(.horizontal, 24)
    }

    // MARK: - Tag Selector

    private var tagSelector: some View {
        let availableTags = getAvailableTags()
        let tagsToUse = showAddNote ? newNoteTags : selectedTags

        return VStack(alignment: .leading, spacing: 8) {
            if availableTags.isEmpty {
                Text("Henüz etiket yok")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(availableTags, id: \.self) { tag in
                        Button(action: {
                            toggleTag(tag)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: tagsToUse.contains(tag) ? "checkmark.circle.fill" : "circle")
                                    .font(.caption)
                                Text(tag)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(tagsToUse.contains(tag) ? Color.blue : Color(UIColor.tertiarySystemBackground))
                            .foregroundColor(tagsToUse.contains(tag) ? .white : .primary)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Project Selector

    private var projectSelector: some View {
        let availableProjects = getAvailableProjects()
        let projectToUse = showAddNote ? newNoteProject : selectedProject

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
                ForEach([""] + availableProjects, id: \.self) { project in
                    Button(action: {
                        if showAddNote {
                            newNoteProject = project
                        } else {
                            selectedProject = project
                        }
                    }) {
                        HStack {
                            Image(systemName: projectToUse == project ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(projectToUse == project ? .blue : .secondary)
                            Text(project.isEmpty ? "Proje Yok" : project)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .foregroundColor(.primary)
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
        if selectedTags.isEmpty && selectedProject.isEmpty {
            filteredNotes = notes
        } else {
            filteredNotes = notes.filter { note in
                let tagMatch = selectedTags.isEmpty || !selectedTags.isDisjoint(with: note.tags)
                let projectMatch = selectedProject.isEmpty || note.project == selectedProject
                return tagMatch && projectMatch
            }
        }
    }

    private func addNewNote() {
        guard !newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let note = Note(
            content: newNoteContent,
            tags: Array(newNoteTags),
            project: newNoteProject
        )
        dataStore.addNote(note)
        loadNotes()

        showAddNote = false
        resetNewNoteFields()
    }

    private func resetNewNoteFields() {
        newNoteContent = ""
        newNoteTags.removeAll()
        newNoteProject = ""
    }

    private func startEditing(_ note: Note) {
        editingNoteID = note.id
        editingContent = note.content
    }

    private func saveNoteEdit(_ note: Note) {
        var updatedNote = note
        updatedNote.content = editingContent
        dataStore.updateNote(updatedNote)
        loadNotes()

        editingNoteID = nil
        editingContent = ""
    }

    private func deleteNote(_ note: Note) {
        dataStore.deleteNote(note)
        loadNotes()
    }

    private func toggleTag(_ tag: String) {
        if showAddNote {
            if newNoteTags.contains(tag) {
                newNoteTags.remove(tag)
            } else {
                newNoteTags.insert(tag)
            }
        } else {
            if selectedTags.contains(tag) {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
        }
    }

    private func getAvailableTags() -> [String] {
        // Get tags from existing notes and tasks
        var tags = Set<String>()
        for note in notes {
            tags.formUnion(note.tags)
        }
        for task in dataStore.getPlannerEvents() {
            if !task.tag.isEmpty {
                tags.insert(task.tag)
            }
        }
        return tags.sorted()
    }

    private func getAvailableProjects() -> [String] {
        // Get projects from existing notes and tasks
        var projects = Set<String>()
        for note in notes {
            if !note.project.isEmpty {
                projects.insert(note.project)
            }
        }
        for task in dataStore.getPlannerEvents() {
            if !task.project.isEmpty {
                projects.insert(task.project)
            }
        }
        return projects.sorted()
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var size: CGSize = .zero
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)

                if currentX + subviewSize.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, subviewSize.height)
                currentX += subviewSize.width + spacing
                size.width = max(size.width, currentX - spacing)
            }

            size.height = currentY + lineHeight
            self.size = size
            self.positions = positions
        }
    }
}
