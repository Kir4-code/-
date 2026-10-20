import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @StateObject private var store = NotebookStore()
    @State private var editingNotebook: Notebook?
    @State private var showingNew = false
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportURL: URL?
    @State private var exportName = "notebook"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    shelf
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationDestination(for: UUID.self) { id in
                NotebookHost(store: store, notebookId: id)
            }
            .sheet(item: $editingNotebook) { nb in
                NotebookEditor(store: store, notebook: nb, isNew: false)
            }
            .sheet(isPresented: $showingNew) {
                NotebookEditor(store: store,
                               notebook: Notebook.new(name: "", cover: .blue),
                               isNew: true)
            }
            .fileExporter(
                isPresented: $showExporter,
                document: KletkaDocument(url: exportURL),
                contentType: .data,
                defaultFilename: exportName
            ) { _ in
                if let u = exportURL { try? FileManager.default.removeItem(at: u) }
                exportURL = nil
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.data, .zip, UTType(filenameExtension: "kletka") ?? .data]
            ) { result in
                guard case .success(let url) = result else { return }
                do {
                    let nb = try NotebookExport.importNotebook(from: url, store: store)
                    store.add(nb)
                } catch {
                    print("Import error: \(error)")
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Тетради")
                    .font(.system(size: 56, weight: .regular, design: .serif))
                Text("\(store.notebooks.count) \(plural(store.notebooks.count, "тетрадь", "тетради", "тетрадей")) в клетку")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button { showImporter = true } label: {
                    Label("Импорт", systemImage: "square.and.arrow.down")
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.gray.opacity(0.15))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button { showingNew = true } label: {
                    Label("Новая тетрадь", systemImage: "plus")
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var shelf: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 24)], spacing: 28) {
            ForEach(store.notebooks) { nb in
                NavigationLink(value: nb.id) {
                    NotebookCover(nb: nb, store: store)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Изменить") { editingNotebook = nb }
                    Button("Экспортировать") {
                        if let url = try? NotebookExport.export(nb, store: store) {
                            exportURL = url
                            exportName = nb.name
                            showExporter = true
                        }
                    }
                    Button("Удалить", role: .destructive) {
                        store.delete(id: nb.id)
                    }
                }
            }
            newTile
        }
    }

    private var newTile: some View {
        Button { showingNew = true } label: {
            VStack(spacing: 10) {
                Image(systemName: "plus").font(.system(size: 28))
                Text("Новая тетрадь").font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3/4, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundStyle(.secondary.opacity(0.5))
            )
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let a = n % 10, b = n % 100
        if a == 1 && b != 11 { return one }
        if a >= 2 && a <= 4 && (b < 10 || b >= 20) { return few }
        return many
    }
}

struct NotebookCover: View {
    let nb: Notebook
    @ObservedObject var store: NotebookStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: nb.cover.hex))

                if let fileName = nb.coverImageFileName,
                   let ui = store.loadCoverImage(fileName: fileName) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(LinearGradient(colors: [.black.opacity(0.3), .black.opacity(0.06)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: 16)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    Text("ТЕТРАДЬ В КЛЕТКУ")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(nb.name)
                        .font(.system(size: 26, design: .serif))
                        .foregroundStyle(.black)
                        .lineLimit(2)
                }
                .padding(10)
                .background(Color(white: 0.99).opacity(nb.coverImageFileName == nil ? 1 : 0.92))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(.leading, 32)
                .padding(.trailing, 16)
                .padding(.top, 40)
            }
            .aspectRatio(3/4, contentMode: .fit)
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)

            Text("Изменена \(relativeDate(nb.updated))")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "сегодня" }
        if cal.isDateInYesterday(date) { return "вчера" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }
}

struct NotebookEditor: View {
    @ObservedObject var store: NotebookStore
    @Environment(\.dismiss) private var dismiss
    @State var notebook: Notebook
    let isNew: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Например, Математика", text: $notebook.name)
                }
                Section("Цвет обложки") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(CoverColor.allCases) { c in
                            Button { notebook.cover = c } label: {
                                Circle()
                                    .fill(Color(hex: c.hex))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle().stroke(notebook.cover == c
                                                        ? Color.accentColor : Color.black.opacity(0.15),
                                                        lineWidth: notebook.cover == c ? 3 : 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !isNew {
                    Section {
                        Button("Удалить тетрадь", role: .destructive) {
                            store.delete(id: notebook.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Новая тетрадь" : "Тетрадь")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Создать" : "Сохранить") {
                        var nb = notebook
                        if nb.name.trimmingCharacters(in: .whitespaces).isEmpty {
                            nb.name = "Без названия"
                        }
                        if isNew { store.add(nb) } else { store.update(nb) }
                        dismiss()
                    }
                }
            }
        }
    }
}

struct NotebookHost: View {
    @ObservedObject var store: NotebookStore
    let notebookId: UUID
    @State private var controller: BoardController?

    var body: some View {
        Group {
            if let c = controller {
                NotebookView(store: store, controller: c)
            } else {
                ProgressView()
                    .onAppear {
                        controller = BoardController(store: store, notebookId: notebookId)
                    }
            }
        }
    }
}
