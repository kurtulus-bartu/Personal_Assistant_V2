// KanbanView.swift
import SwiftUI
import UniformTypeIdentifiers

struct KanbanView: View {
    @Binding var events: [PlannerEvent]
    @Binding var selectedTag: String?
    @Binding var selectedProject: String?
    var onAddEvent: (() -> Void)?
    var onEditEvent: ((PlannerEvent) -> Void)?
    
    @State private var draggedEvent: PlannerEvent?
    @State private var showingEventForm = false
    
    @State private var customTags: [String] = []
    @State private var customProjects: [String] = []
    @State private var projectTagMap: [String: String] = [:] // proje -> tag
    
    private enum Popup { case tagAdd, tagEdit, projectAdd, projectEdit }
    @State private var activePopup: Popup? = nil
    @State private var tagNameField: String = ""
    @State private var projectNameField: String = ""
    @State private var chosenTagForProject: String = ""
    
    private let smallControlSize: CGFloat = 30
    
    // Ortak yüzey rengi: koyu gri (sistem "surface")
    private var surface: Color { Color(UIColor.secondarySystemBackground) }
    
    // --- Derived ---
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
    private var filteredEvents: [PlannerEvent] {
        events.filter { e in
            guard e.isTask else { return false }
            var ok = true
            if let t = selectedTag, !t.isEmpty { ok = ok && normalize(e.tag) == normalize(t) }
            if let p = selectedProject, !p.isEmpty { ok = ok && normalize(e.project) == normalize(p) }
            return ok
        }
    }
    private func eventsForStatus(_ status: String) -> [PlannerEvent] {
        filteredEvents.filter { $0.task == status }.sorted { $0.endDate < $1.endDate }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerView
                filterView
                Divider()
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        kanbanColumn(title: "To Do",       status: "To Do")
                        kanbanColumn(title: "In Progress", status: "In Progress")
                        kanbanColumn(title: "Done",        status: "Done")
                    }
                    .padding()
                }
            }
            .background(Color(UIColor.systemBackground))
            
            if let popup = activePopup {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { dismissPopup() }
                
                switch popup {
                case .tagAdd:
                    TagPopup(title: "Tag Ekle",
                             name: $tagNameField,
                             primaryTitle: "Kaydet",
                             accent: .blue,
                             showDelete: false,
                             onPrimary: saveNewTag,
                             onDelete: nil,
                             onCancel: dismissPopup,
                             panelStyle: surface)
                    
                case .tagEdit:
                    TagPopup(title: "Tag Düzenle",
                             name: $tagNameField,
                             primaryTitle: "Kaydet",
                             accent: .blue,
                             showDelete: true,
                             onPrimary: saveEditedTag,
                             onDelete: deleteCurrentTag,
                             onCancel: dismissPopup,
                             panelStyle: surface)
                    
                case .projectAdd:
                    ProjectPopup(title: "Proje Ekle",
                                 name: $projectNameField,
                                 selectedTag: $chosenTagForProject,
                                 tags: allTags,
                                 primaryTitle: "Kaydet",
                                 showDelete: false,
                                 accent: .green,
                                 onPrimary: saveNewProject,
                                 onDelete: nil,
                                 onGoToProjectPage: goToProjectPage,
                                 onCancel: dismissPopup,
                                 panelStyle: surface)
                    
                case .projectEdit:
                    ProjectPopup(title: "Proje Düzenle",
                                 name: $projectNameField,
                                 selectedTag: $chosenTagForProject,
                                 tags: allTags,
                                 primaryTitle: "Kaydet",
                                 showDelete: true,
                                 accent: .green,
                                 onPrimary: saveEditedProject,
                                 onDelete: deleteCurrentProject,
                                 onGoToProjectPage: goToProjectPage,
                                 onCancel: dismissPopup,
                                 panelStyle: surface)
                }
            }
        }
        .sheet(isPresented: $showingEventForm) {
            EventFormView(
                isPresented: $showingEventForm,
                allEvents: events,
                allTags: allTags,
                allProjects: allProjects,
                onSave: { events.append($0) }
            )
        }
    }
    
    // Header
    private var headerView: some View {
        HStack(spacing: 12) {
            Text("Kanban")
                .font(.title2).fontWeight(.semibold)
            Spacer()
            smallSquareButton(systemName: "plus") {
                if let onAddEvent { onAddEvent() } else { showingEventForm = true }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(Color(UIColor.systemBackground))
    }
    
    // Filters
    private var filterView: some View {
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
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // Column
    private func kanbanColumn(title: String, status: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline).fontWeight(.semibold)
                Spacer()
                Text("\(eventsForStatus(status).count)")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2)).cornerRadius(12)
            }
            .padding(.horizontal, 12).padding(.top, 12)
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    ForEach(eventsForStatus(status)) { event in
                        kanbanCard(event: event)
                            .onTapGesture(count: 2) { onEditEvent?(event) }
                            .onDrag { self.draggedEvent = event; return NSItemProvider(object: event.id.uuidString as NSString) }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 12)
            }
            .frame(minHeight: 200)
        }
        .frame(width: 300)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .onDrop(of: [UTType.text],
                delegate: KanbanDropDelegate(status: status, events: $events, draggedEvent: $draggedEvent))
    }
    
    // Card
    private func kanbanCard(event: PlannerEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(metadataLine(for: event))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                // Pomodoro sayısı
                if !event.pomodoroSessions.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                            .font(.caption2)
                        Text("\(event.pomodoroSessions.count)")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }

                Text(event.endDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface) // <-- siyah değil, sistem koyu gri yüzey
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 5, y: 3)
    }
    
    private func metadataLine(for e: PlannerEvent) -> String {
        var parts: [String] = []
        if !e.tag.isEmpty { parts.append(e.tag) }
        if !e.project.isEmpty { parts.append(e.project) }
        if let pid = e.parentID, let p = events.first(where: { $0.id == pid }) {
            parts.append(p.title)
        }
        return parts.joined(separator: " • ")
    }
    
    // UI helpers
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
    
    // Data ops
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
        if let sp = selectedProject, let m = projectTagMap[sp], normalize(m) != normalize(new) { selectedProject = nil }
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
    private func goToProjectPage() { print("Detay: \(projectNameField)"); dismissPopup() }
    
    private func dismissPopup() { activePopup = nil }
    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Locale.current)
    }
}

// Drop Delegate
struct KanbanDropDelegate: DropDelegate {
    let status: String
    @Binding var events: [PlannerEvent]
    @Binding var draggedEvent: PlannerEvent?
    
    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [UTType.text]) }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        guard let item = draggedEvent else { return false }
        if let idx = events.firstIndex(where: { $0.id == item.id }) { events[idx].task = status }
        self.draggedEvent = nil
        return true
    }
}

// Pop-uplar
private struct TagPopup: View {
    let title: String
    @Binding var name: String
    let primaryTitle: String
    var accent: Color
    var showDelete: Bool
    var onPrimary: () -> Void
    var onDelete: (() -> Void)?
    var onCancel: () -> Void
    var panelStyle: Color   // <-- surface
    
    var body: some View {
        PopupCard(panelStyle: panelStyle) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.headline)
                TextField("Ad", text: $name)
                    .textInputAutocapitalization(.never)
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                HStack {
                    Button("Detay") {}.hidden() // hizalama için yer tutucu
                    Spacer()
                    if showDelete, let onDelete {
                        Button(role: .destructive, action: onDelete) { Label("Sil", systemImage: "trash") }
                    }
                    Button(action: onPrimary) { Text(primaryTitle).fontWeight(.semibold) }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ProjectPopup: View {
    let title: String
    @Binding var name: String
    @Binding var selectedTag: String
    var tags: [String]
    let primaryTitle: String
    var showDelete: Bool
    var accent: Color
    var onPrimary: () -> Void
    var onDelete: (() -> Void)?
    var onGoToProjectPage: () -> Void  // "Detay"
    var onCancel: () -> Void
    var panelStyle: Color   // <-- surface
    
    var body: some View {
        PopupCard(panelStyle: panelStyle) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.headline)
                
                TextField("Proje adı", text: $name)
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("İlişkili Tag").font(.caption).foregroundColor(.secondary)
                    Menu {
                        ForEach(tags, id: \.self) { tag in Button(tag) { selectedTag = tag } }
                    } label: {
                        HStack {
                            Text(selectedTag.isEmpty ? "—" : selectedTag)
                            Spacer()
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                HStack {
                    Button("Detay", action: onGoToProjectPage)
                    Spacer()
                    if showDelete, let onDelete {
                        Button(role: .destructive, action: onDelete) { Label("Sil", systemImage: "trash") }
                    }
                    Button(action: onPrimary) { Text(primaryTitle).fontWeight(.semibold) }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct PopupCard<Content: View>: View {
    var panelStyle: Color  // <-- surface
    let content: () -> Content
    
    var body: some View {
        VStack { content() }
            .padding(16)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(panelStyle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 24)
    }
}
