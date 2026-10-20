import Foundation
import SwiftUI
import Combine

@MainActor
final class BoardController: ObservableObject {

    @Published var prefs: ToolPreferences {
        didSet { board.prefs = prefs; store.prefs = prefs; store.scheduleSave() }
    }

    let store: NotebookStore
    private(set) var notebookId: UUID
    let board = BoardView()

    private var undoStack: [[CanvasItem]] = []
    private var redoStack: [[CanvasItem]] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    init(store: NotebookStore, notebookId: UUID) {
        self.store = store
        self.notebookId = notebookId
        self.prefs = store.prefs

        if let nb = store.notebook(id: notebookId) {
            board.applyNotebook(nb)
        }
        board.prefs = prefs

        board.onItemsChanged = { [weak self] items in
            self?.handleItemsChanged(items)
        }
        board.onViewChanged = { [weak self] x, y, s in
            self?.handleViewChanged(x: x, y: y, scale: s)
        }
    }

    private func handleItemsChanged(_ items: [CanvasItem]) {
        guard let nb = store.notebook(id: notebookId) else { return }
        pushUndo(nb.items)
        var updated = nb
        updated.items = items
        updated.viewX = board.viewX
        updated.viewY = board.viewY
        updated.viewScale = board.viewScale
        store.update(updated)
        objectWillChange.send()
    }

    private func handleViewChanged(x: CGFloat, y: CGFloat, scale: CGFloat) {
        guard let nb = store.notebook(id: notebookId) else { return }
        var updated = nb
        updated.viewX = x
        updated.viewY = y
        updated.viewScale = scale
        store.update(updated)
    }

    private func pushUndo(_ items: [CanvasItem]) {
        undoStack.append(items)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func undo() {
        guard let prev = undoStack.popLast(),
              let nb = store.notebook(id: notebookId) else { return }
        redoStack.append(nb.items)
        var updated = nb
        updated.items = prev
        store.update(updated)
        board.applyNotebook(updated)
        objectWillChange.send()
    }

    func redo() {
        guard let next = redoStack.popLast(),
              let nb = store.notebook(id: notebookId) else { return }
        undoStack.append(nb.items)
        var updated = nb
        updated.items = next
        store.update(updated)
        board.applyNotebook(updated)
        objectWillChange.send()
    }

    func selectTool(_ tool: ToolKind) {
        prefs.selectedTool = tool
    }

    func zoomIn()  { board.zoomBy(1.25) }
    func zoomOut() { board.zoomBy(1 / 1.25) }
    func resetZoom() { board.setView(x: board.viewX, y: board.viewY, scale: 1) }

    func saveViewIfNeeded() {
        handleViewChanged(x: board.viewX, y: board.viewY, scale: board.viewScale)
    }
}
