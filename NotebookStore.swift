import Foundation
import Combine
import CoreGraphics
import UIKit

@MainActor
final class NotebookStore: ObservableObject {
    @Published private(set) var notebooks: [Notebook] = []
    @Published var prefs: ToolPreferences = ToolPreferences()

    private let fileURL: URL
    private let prefsURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Kletka", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: dir.appendingPathComponent("Images", isDirectory: true),
                                                 withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: dir.appendingPathComponent("Covers", isDirectory: true),
                                                 withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("notebooks.json")
        self.prefsURL = dir.appendingPathComponent("prefs.json")
        load()
    }

    // MARK: - Загрузка / сохранение

    private func load() {
        let decoder = JSONDecoder()
        if let data = try? Data(contentsOf: fileURL),
           let list = try? decoder.decode([Notebook].self, from: data) {
            notebooks = list
        } else {
            notebooks = Self.demoNotebooks()
        }
        if let data = try? Data(contentsOf: prefsURL),
           let p = try? decoder.decode(ToolPreferences.self, from: data) {
            prefs = p
        }
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(notebooks) {
            try? data.write(to: fileURL, options: .atomic)
        }
        if let data = try? encoder.encode(prefs) {
            try? data.write(to: prefsURL, options: .atomic)
        }
    }

    // MARK: - CRUD

    func add(_ nb: Notebook) {
        notebooks.append(nb)
        scheduleSave()
    }

    func update(_ nb: Notebook) {
        if let i = notebooks.firstIndex(where: { $0.id == nb.id }) {
            notebooks[i] = nb
            notebooks[i].updated = Date()
            scheduleSave()
        }
    }

    func delete(id: UUID) {
        notebooks.removeAll { $0.id == id }
        scheduleSave()
    }

    func notebook(id: UUID) -> Notebook? {
        notebooks.first { $0.id == id }
    }

    // MARK: - Пути к картинкам

    var imagesDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Kletka/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var coversDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Kletka/Covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func imageURL(fileName: String) -> URL? {
        let url = imagesDir.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func loadCoverImage(fileName: String) -> UIImage? {
        let url = coversDir.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func saveCoverImage(data: Data, fileName: String) throws {
        try data.write(to: coversDir.appendingPathComponent(fileName))
    }

    // MARK: - Демка

    static func demoNotebooks() -> [Notebook] {
        let cell: CGFloat = 26
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * cell, y: y * cell) }

        var math = Notebook.new(name: "Математика", cover: .blue)
        var graphPoints: [CGPoint] = []
        var graphPressures: [CGFloat] = []
        var x: CGFloat = 6.2
        while x <= 15.8 {
            graphPoints.append(p(x, 13 - pow(x - 11, 2) / 2))
            graphPressures.append(0.6)
            x += 0.2
        }
        let graph = Stroke(kind: .pen, colorHex: InkColor.blue.lightHex, width: 2.6,
                           points: graphPoints, pressures: graphPressures)
        let axisX = LineShape(dashed: false, colorHex: InkColor.ink.lightHex, width: 2.6,
                              start: p(2, 9), end: p(20, 9))
        let axisY = LineShape(dashed: false, colorHex: InkColor.ink.lightHex, width: 2.6,
                              start: p(11, 1), end: p(11, 16))
        let dashed = LineShape(dashed: true, colorHex: InkColor.red.lightHex, width: 2.2,
                               start: p(7, 13), end: p(15, 13))
        let sticker = Sticker(color: .yellow,
                              frame: CGRect(x: 22 * cell, y: 1 * cell, width: 7 * cell, height: 5 * cell),
                              text: "y = (x − 11)² / 2 − 4\nВершина: (11; −4)")
        math.items = [.line(axisX), .line(axisY), .stroke(graph), .line(dashed), .sticker(sticker)]

        let physics = Notebook.new(name: "Физика", cover: .orange)
        return [math, physics]
    }
}
