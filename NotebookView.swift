import SwiftUI
import PhotosUI

struct NotebookView: View {
    @ObservedObject var store: NotebookStore
    @ObservedObject var controller: BoardController
    @Environment(\.dismiss) private var dismiss
    @State private var pickedImage: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            BoardContainer(board: controller.board)
            Divider()
            toolBar
            optionsBar
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: pickedImage) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    let aspect = ui.size.width / max(ui.size.height, 1)
                    let h: CGFloat = 240 / max(aspect, 1)
                    let w: CGFloat = h * aspect
                    controller.board.placeImage(data: data, worldSize: CGSize(width: w, height: h))
                }
                pickedImage = nil
            }
        }
        .onDisappear {
            controller.saveViewIfNeeded()
            store.saveNow()
        }
    }

    // MARK: - Верхняя панель

    private var topBar: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Label("Тетради", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)

            Text(store.notebook(id: controller.notebookId)?.name ?? "")
                .font(.system(size: 26, design: .serif))
                .lineLimit(1)

            Spacer()

            Button {
                controller.prefs.fingerDraws.toggle()
            } label: {
                Text(controller.prefs.fingerDraws ? "Палец: рисует" : "Палец: листает")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(controller.prefs.fingerDraws
                                               ? Color.accentColor.opacity(0.15)
                                               : Color.gray.opacity(0.15)))
            }
            .buttonStyle(.plain)

            Button { controller.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!controller.canUndo)
            Button { controller.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!controller.canRedo)

            Button { controller.zoomOut() } label: { Image(systemName: "minus.magnifyingglass") }
            Button { controller.resetZoom() } label: {
                Text("100%").font(.system(size: 13, weight: .medium))
            }
            Button { controller.zoomIn() } label: { Image(systemName: "plus.magnifyingglass") }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color(.systemBackground))
    }

    // MARK: - Инструменты

    private var toolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ToolKind.allCases) { tool in
                    toolButton(tool)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func toolButton(_ tool: ToolKind) -> some View {
        if tool == .image {
            PhotosPicker(selection: $pickedImage, matching: .images) {
                VStack(spacing: 3) {
                    Image(systemName: "photo").font(.system(size: 20))
                    Text(tool.title).font(.system(size: 10, weight: .medium))
                }
                .frame(minWidth: 60)
                .padding(.vertical, 6)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                controller.selectTool(tool)
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: iconName(for: tool)).font(.system(size: 20))
                    Text(tool.title).font(.system(size: 10, weight: .medium))
                }
                .frame(minWidth: 60)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(controller.prefs.selectedTool == tool
                              ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .foregroundStyle(controller.prefs.selectedTool == tool
                                 ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func iconName(for tool: ToolKind) -> String {
        switch tool {
        case .pen:         return "pencil.tip"
        case .pencil:      return "pencil"
        case .highlighter: return "highlighter"
        case .eraser:      return "eraser"
        case .line:        return "line.diagonal"
        case .dash:        return "line.diagonal"
        case .sticker:     return "note.text"
        case .image:       return "photo"
        case .hand:        return "hand.draw"
        }
    }

    // MARK: - Настройки/параметры

    private var optionsBar: some View {
        HStack(spacing: 8) {
            if controller.prefs.selectedTool.isDrawing
                || controller.prefs.selectedTool == .line
                || controller.prefs.selectedTool == .dash {
                Text("Цвет:").font(.system(size: 12)).foregroundStyle(.secondary)
                ForEach(InkColor.allCases) { color in
                    ColorDot(hex: color.lightHex,
                             selected: isColorSelected(color)) {
                        selectColor(color)
                    }
                }
            }
            if controller.prefs.selectedTool == .highlighter {
                ForEach(HighlighterColor.allCases) { color in
                    ColorDot(hex: color.hex,
                             selected: controller.prefs.highlighterColor == color) {
                        controller.prefs.highlighterColor = color
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 52)
        .background(Color(.systemBackground))
    }

    private func isColorSelected(_ c: InkColor) -> Bool {
        switch controller.prefs.selectedTool {
        case .pen:    return controller.prefs.penColor == c
        case .pencil: return controller.prefs.pencilColor == c
        case .line:   return controller.prefs.lineColor == c
        case .dash:   return controller.prefs.dashColor == c
        default:      return false
        }
    }

    private func selectColor(_ c: InkColor) {
        switch controller.prefs.selectedTool {
        case .pen:    controller.prefs.penColor = c
        case .pencil: controller.prefs.pencilColor = c
        case .line:   controller.prefs.lineColor = c
        case .dash:   controller.prefs.dashColor = c
        default: break
        }
    }
}

struct BoardContainer: UIViewRepresentable {
    let board: BoardView
    func makeUIView(context: Context) -> BoardView { board }
    func updateUIView(_ uiView: BoardView, context: Context) {}
}

struct ColorDot: View {
    let hex: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle().stroke(selected ? Color.accentColor : Color.black.opacity(0.15),
                                    lineWidth: selected ? 2.5 : 1)
                )
                .padding(2)
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    init(hex: String) {
        let ui = UIColor(hex: hex)
        self.init(uiColor: ui)
    }
}
