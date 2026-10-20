import UIKit
import SwiftUI

final class BoardView: UIView {

    // MARK: - Модель

    var notebook: Notebook = Notebook.new(name: "", cover: .blue) {
        didSet { setNeedsDisplay(); rebuildOverlays() }
    }

    var prefs: ToolPreferences = ToolPreferences() {
        didSet { setNeedsDisplay() }
    }

    private var pencilActive = false
    private var pencilReleaseTimer: Timer?

    var onItemsChanged: (([CanvasItem]) -> Void)?
    var onViewChanged: ((CGFloat, CGFloat, CGFloat) -> Void)?

    // MARK: - Вид

    var viewX: CGFloat = 0
    var viewY: CGFloat = 0
    var viewScale: CGFloat = 1

    // MARK: - Рисовальки

    private var currentStroke: Stroke?
    private var currentLine: LineShape?
    private var currentPressure: CGFloat = 0.5
    private var lastPoint: CGPoint = .zero
    private var holdTimer: Timer?
    private var strokeStartScreen: CGPoint = .zero

    // MARK: - Жесты

    private var activeTouchId: UITouch?
    private var isPanning = false
    private var isPinching = false
    private var pinchStartDistance: CGFloat = 0
    private var pinchStartScale: CGFloat = 1
    private var pinchStartView: CGPoint = .zero
    private var pinchStartCenter: CGPoint = .zero

    // MARK: - Оверлей

    private var stickerViews: [UUID: StickerView] = [:]
    private var imageViews: [UUID: ImageView] = [:]

    private let cell: CGFloat = 26

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        isOpaque = false
        contentMode = .redraw
    }

    // MARK: - Коорды

    private func worldPoint(from screen: CGPoint) -> CGPoint {
        CGPoint(x: (screen.x - viewX) / viewScale,
                y: (screen.y - viewY) / viewScale)
    }

    func worldRect(from screen: CGRect) -> CGRect {
        CGRect(x: (screen.origin.x - viewX) / viewScale,
               y: (screen.origin.y - viewY) / viewScale,
               width: screen.width / viewScale,
               height: screen.height / viewScale)
    }

    private func screenRect(from world: CGRect) -> CGRect {
        CGRect(x: world.origin.x * viewScale + viewX,
               y: world.origin.y * viewScale + viewY,
               width: world.width * viewScale,
               height: world.height * viewScale)
    }

    private func image(for item: ImageItem) -> UIImage? {
        let url = imagePath(fileName: item.fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func imagePath(fileName: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Kletka/Images/\(fileName)")
    }

    // MARK: - Отрисовка

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let isDark = traitCollection.userInterfaceStyle == .dark
        let paper = isDark ? UIColor(hex: "#141a26") : UIColor(hex: "#fbfcfe")
        let gridColor = isDark ? UIColor(hex: "#232d44") : UIColor(hex: "#cfdcf0")
        paper.setFill()
        ctx.fill(bounds)

        drawGrid(ctx: ctx, color: gridColor)

        ctx.saveGState()
        ctx.translateBy(x: viewX, y: viewY)
        ctx.scaleBy(x: viewScale, y: viewScale)

        for item in notebook.items {
            switch item {
            case .stroke(let s):  drawStroke(ctx: ctx, stroke: s)
            case .line(let l):    drawLine(ctx: ctx, line: l)
            case .sticker:        break
            case .image(let i):   image(for: i)?.draw(in: i.frame)
            }
        }

        if let s = currentStroke { drawStroke(ctx: ctx, stroke: s) }
        if let l = currentLine { drawLine(ctx: ctx, line: l) }

        ctx.restoreGState()
    }

    private func drawGrid(ctx: CGContext, color: UIColor) {
        let step = cell * viewScale
        guard step > 4 else { return }
        color.setStroke()
        ctx.setLineWidth(1 / UIScreen.main.scale)
        var x = viewX.truncatingRemainder(dividingBy: step)
        if x < 0 { x += step }
        var y = viewY.truncatingRemainder(dividingBy: step)
        if y < 0 { y += step }

        ctx.beginPath()
        while x <= bounds.width {
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: bounds.height))
            x += step
        }
        while y <= bounds.height {
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: bounds.width, y: y))
            y += step
        }
        ctx.strokePath()
    }

    private func drawStroke(ctx: CGContext, stroke: Stroke) {
        guard !stroke.points.isEmpty else { return }
        let color = UIColor(hex: stroke.colorHex)
        let alpha: CGFloat = stroke.kind == .highlighter ? 0.4 : 1.0
        ctx.setStrokeColor(color.withAlphaComponent(alpha).cgColor)
        ctx.setFillColor(color.withAlphaComponent(alpha).cgColor)
        ctx.setLineWidth(stroke.width)
        ctx.setLineCap(stroke.kind == .highlighter ? .butt : .round)
        ctx.setLineJoin(.round)

        if stroke.points.count == 1 {
            let p = stroke.points[0]
            let r = stroke.width / 2
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            return
        }

        ctx.beginPath()
        ctx.move(to: stroke.points[0])
        if stroke.points.count == 2 {
            ctx.addLine(to: stroke.points[1])
        } else {
            for i in 1..<stroke.points.count - 1 {
                let mid = CGPoint(x: (stroke.points[i].x + stroke.points[i+1].x) / 2,
                                  y: (stroke.points[i].y + stroke.points[i+1].y) / 2)
                ctx.addQuadCurve(to: mid, control: stroke.points[i])
            }
            if let last = stroke.points.last { ctx.addLine(to: last) }
        }
        ctx.strokePath()
    }

    private func drawLine(ctx: CGContext, line: LineShape) {
        let color = UIColor(hex: line.colorHex)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(line.width)
        ctx.setLineCap(line.dashed ? .butt : .round)
        if line.dashed {
            ctx.setLineDash(phase: 0, lengths: [line.width * 2 + 9, line.width * 1.5 + 8])
        } else {
            ctx.setLineDash(phase: 0, lengths: [])
        }
        ctx.beginPath()
        ctx.move(to: line.start)
        ctx.addLine(to: line.end)
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])
    }

    // MARK: - Оверлеи (стикеры и картинки)

    private func rebuildOverlays() {
        rebuildStickerViews()
        rebuildImageViews()
    }

    private func rebuildStickerViews() {
        let ids = Set(notebook.items.compactMap {
            if case .sticker(let s) = $0 { return s.id } else { return nil }
        })
        for (id, v) in stickerViews where !ids.contains(id) {
            v.removeFromSuperview()
            stickerViews.removeValue(forKey: id)
        }
        for item in notebook.items {
            guard case .sticker(let s) = item else { continue }
            let v = stickerViews[s.id] ?? {
                let sv = StickerView(sticker: s)
                sv.onChange = { [weak self] newSticker in self?.updateSticker(newSticker) }
                sv.onDelete = { [weak self] id in self?.deleteSticker(id: id) }
                sv.onMove = { [weak self] newSticker in self?.updateSticker(newSticker) }
                stickerViews[s.id] = sv
                addSubview(sv)
                return sv
            }()
            v.update(sticker: s)
            v.frame = screenRect(from: s.frame)
        }
    }

    private func rebuildImageViews() {
        let ids = Set(notebook.items.compactMap {
            if case .image(let i) = $0 { return i.id } else { return nil }
        })
        for (id, v) in imageViews where !ids.contains(id) {
            v.removeFromSuperview()
            imageViews.removeValue(forKey: id)
        }
        for item in notebook.items {
            guard case .image(let i) = item else { continue }
            if let existing = imageViews[i.id] {
                existing.update(item: i)
                existing.frame = screenRect(from: i.frame)
            } else if let ui = image(for: i) {
                let iv = ImageView(item: i, image: ui)
                iv.onMove = { [weak self] newItem in self?.updateImage(newItem) }
                iv.onDelete = { [weak self] id in self?.deleteImage(id: id) }
                imageViews[i.id] = iv
                addSubview(iv)
                iv.frame = screenRect(from: i.frame)
            }
        }
    }

    private func updateSticker(_ sticker: Sticker) {
        var items = notebook.items
        if let idx = items.firstIndex(where: { $0.id == sticker.id }) {
            items[idx] = .sticker(sticker)
            notebook.items = items
            rebuildStickerViews()
            onItemsChanged?(items)
            setNeedsDisplay()
        }
    }

    private func deleteSticker(id: UUID) {
        var items = notebook.items
        items.removeAll { $0.id == id }
        notebook.items = items
        rebuildStickerViews()
        onItemsChanged?(items)
        setNeedsDisplay()
    }

    private func updateImage(_ item: ImageItem) {
        var items = notebook.items
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = .image(item)
            notebook.items = items
            rebuildImageViews()
            onItemsChanged?(items)
            setNeedsDisplay()
        }
    }

    private func deleteImage(id: UUID) {
        var items = notebook.items
        items.removeAll { $0.id == id }
        notebook.items = items
        rebuildImageViews()
        onItemsChanged?(items)
        setNeedsDisplay()
    }

    // MARK: - Касания

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.contains(where: { $0.type == .pencil }) {
            pencilActive = true
            pencilReleaseTimer?.invalidate()
            pencilReleaseTimer = nil
        }
        if pencilActive, touches.allSatisfy({ $0.type == .direct }) { return }

        let totalDirect = event?.allTouches?.filter { $0.type == .direct }.count ?? 0
        if totalDirect >= 2 {
            if activeTouchId?.type == .direct {
                currentStroke = nil
                currentLine = nil
                holdTimer?.invalidate(); holdTimer = nil
                activeTouchId = nil
                isPanning = false
                setNeedsDisplay()
            }
            if !isPinching, let all = event?.allTouches?.filter({ $0.type == .direct }), all.count >= 2 {
                let arr = Array(all)
                let p0 = arr[0].location(in: self)
                let p1 = arr[1].location(in: self)
                pinchStartDistance = hypot(p0.x - p1.x, p0.y - p1.y)
                pinchStartScale = viewScale
                pinchStartView = CGPoint(x: viewX, y: viewY)
                pinchStartCenter = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
                isPinching = true
            }
            return
        }

        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        if activeTouchId != nil, activeTouchId !== touch, touch.type != .pencil { return }
        if touch.type == .direct && touch.majorRadius > 40 { return }

        activeTouchId = touch

        let isPencil = touch.type == .pencil
        let shouldDraw = isPencil || (prefs.fingerDraws && prefs.selectedTool != .hand)
        if !shouldDraw {
            isPanning = true
            lastPoint = loc
            return
        }

        currentPressure = isPencil ? touch.force / max(touch.maximumPossibleForce, 1) : 0.5
        strokeStartScreen = loc
        lastPoint = loc
        let wp = worldPoint(from: loc)

        switch prefs.selectedTool {
        case .pen, .pencil, .highlighter:
            let colorHex: String
            switch prefs.selectedTool {
            case .pen:         colorHex = prefs.penColor.lightHex
            case .pencil:      colorHex = prefs.pencilColor.lightHex
            case .highlighter: colorHex = prefs.highlighterColor.hex
            default:           colorHex = "#000"
            }
            let sizeIdx: Int
            switch prefs.selectedTool {
            case .pen:         sizeIdx = prefs.penSize
            case .pencil:      sizeIdx = prefs.pencilSize
            case .highlighter: sizeIdx = prefs.highlighterSize
            default:           sizeIdx = 0
            }
            currentStroke = Stroke(kind: prefs.selectedTool,
                                   colorHex: colorHex,
                                   width: ToolSizes.inkWidth(for: prefs.selectedTool, sizeIndex: sizeIdx),
                                   points: [wp],
                                   pressures: [currentPressure])
            armHoldTimer()

        case .line, .dash:
            let isDash = prefs.selectedTool == .dash
            let color = isDash ? prefs.dashColor.lightHex : prefs.lineColor.lightHex
            let sizeIdx = isDash ? prefs.dashSize : prefs.lineSize
            var start = wp
            if prefs.snapToGrid {
                start = CGPoint(x: round(start.x / cell) * cell,
                                y: round(start.y / cell) * cell)
            }
            currentLine = LineShape(dashed: isDash, colorHex: color,
                                    width: ToolSizes.inkWidth(for: prefs.selectedTool, sizeIndex: sizeIdx),
                                    start: start, end: start)

        case .eraser:
            erase(at: loc)

        case .sticker:
            placeSticker(at: wp)

        case .image, .hand:
            isPanning = true
            lastPoint = loc
        }
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isPinching, let all = event?.allTouches?.filter({ $0.type == .direct }), all.count >= 2 {
            let arr = Array(all)
            let p0 = arr[0].location(in: self)
            let p1 = arr[1].location(in: self)
            let dist = hypot(p0.x - p1.x, p0.y - p1.y)
            let newScale = max(0.15, min(6, pinchStartScale * (dist / max(pinchStartDistance, 1))))
            let center = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
            let worldAtStart = CGPoint(x: (pinchStartCenter.x - pinchStartView.x) / pinchStartScale,
                                       y: (pinchStartCenter.y - pinchStartView.y) / pinchStartScale)
            viewScale = newScale
            viewX = center.x - worldAtStart.x * newScale
            viewY = center.y - worldAtStart.y * newScale
            rebuildOverlays()
            setNeedsDisplay()
            return
        }

        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        if isPanning {
            let dx = loc.x - lastPoint.x
            let dy = loc.y - lastPoint.y
            viewX += dx; viewY += dy
            lastPoint = loc
            rebuildOverlays()
            setNeedsDisplay()
            return
        }

        let movedFromLast = hypot(loc.x - lastPoint.x, loc.y - lastPoint.y)
        if movedFromLast < 1.5 {
            if holdTimer == nil && currentStroke != nil { armHoldTimer() }
        } else {
            holdTimer?.invalidate(); holdTimer = nil
        }
        lastPoint = loc

        let wp = worldPoint(from: loc)

        if let stroke = currentStroke {
            let pressure = touch.type == .pencil ? touch.force / max(touch.maximumPossibleForce, 1) : 0.5
            var s = stroke
            s.points.append(wp)
            s.pressures.append(pressure)
            currentStroke = s
            setNeedsDisplay()
        } else if var line = currentLine {
            var end = wp
            if prefs.snapAxis {
                let dx = abs(end.x - line.start.x)
                let dy = abs(end.y - line.start.y)
                if dy < dx * 0.09 { end.y = line.start.y }
                if dx < dy * 0.09 { end.x = line.start.x }
            }
            if prefs.snapToGrid {
                end = CGPoint(x: round(end.x / cell) * cell,
                              y: round(end.y / cell) * cell)
            }
            line.end = end
            currentLine = line
            setNeedsDisplay()
        } else if prefs.selectedTool == .eraser {
            erase(at: loc)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        holdTimer?.invalidate(); holdTimer = nil
        activeTouchId = nil

        if isPinching {
            isPinching = false
            onViewChanged?(viewX, viewY, viewScale)
            return
        }
        if isPanning {
            isPanning = false
            onViewChanged?(viewX, viewY, viewScale)
            return
        }

        if let stroke = currentStroke {
            var items = notebook.items
            items.append(.stroke(stroke))
            notebook.items = items
            onItemsChanged?(items)
            currentStroke = nil
            setNeedsDisplay()
        }
        if let line = currentLine {
            var items = notebook.items
            items.append(.line(line))
            notebook.items = items
            onItemsChanged?(items)
            currentLine = nil
            setNeedsDisplay()
        }

        if touches.contains(where: { $0.type == .pencil }) {
            pencilReleaseTimer?.invalidate()
            pencilReleaseTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
                self?.pencilActive = false
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        holdTimer?.invalidate(); holdTimer = nil
        currentStroke = nil
        currentLine = nil
        activeTouchId = nil
        isPanning = false
        isPinching = false
        setNeedsDisplay()
    }

    // MARK: - Выпрямление как у айоса

    private func armHoldTimer() {
        holdTimer?.invalidate()
        guard prefs.straightenOnHold, currentStroke != nil else { return }
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: false) { [weak self] _ in
            self?.straightenCurrentStroke()
        }
    }

    private func straightenCurrentStroke() {
        guard let stroke = currentStroke, stroke.points.count >= 6 else { return }
        let pts = stroke.points
        let first = pts.first!
        let last = pts.last!
        let bbox = pts.reduce(CGRect(origin: pts[0], size: .zero)) { r, p in
            r.union(CGRect(origin: p, size: .zero))
        }
        let chord = hypot(last.x - first.x, last.y - first.y)
        var length: CGFloat = 0
        for i in 1..<pts.count {
            length += hypot(pts[i].x - pts[i-1].x, pts[i].y - pts[i-1].y)
        }
        guard length > 30 else { return }

        if chord < length * 0.3 {
            let cx = bbox.midX, cy = bbox.midY
            let rx = bbox.width / 2, ry = bbox.height / 2
            guard rx > 8 && ry > 8 else { return }
            let isCircle = abs(rx - ry) / max(rx, ry) < 0.18
            let newPts: [CGPoint] = (0...72).map { i -> CGPoint in
                let a = CGFloat(i) / 72 * .pi * 2
                if isCircle {
                    let r = (rx + ry) / 2
                    return CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
                } else {
                    return CGPoint(x: cx + rx * cos(a), y: cy + ry * sin(a))
                }
            }
            var s = stroke
            s.points = newPts
            currentStroke = s
            setNeedsDisplay()
        } else {
            var line = LineShape(dashed: false, colorHex: stroke.colorHex,
                                 width: stroke.width, start: first, end: last)
            if prefs.snapAxis {
                let dx = abs(last.x - first.x)
                let dy = abs(last.y - first.y)
                if dy < dx * 0.09 { line.end.y = first.y }
                if dx < dy * 0.09 { line.end.x = first.x }
            }
            currentStroke = nil
            currentLine = line
            setNeedsDisplay()
        }
        holdTimer?.invalidate()
        holdTimer = nil
    }

    // MARK: - Ластик (логика "волшебного")

    private func erase(at screen: CGPoint) {
        let wp = worldPoint(from: screen)
        let r = ToolSizes.eraserRadius(sizeIndex: prefs.eraserSize)
        let hitRadius = max(r / viewScale, 2)
        var items = notebook.items
        let before = items.count
        items.removeAll { item in
            switch item {
            case .stroke(let s):
                return s.points.contains { hypot($0.x - wp.x, $0.y - wp.y) < hitRadius + s.width / 2 }
            case .line(let l):
                return distanceToSegment(p: wp, a: l.start, b: l.end) < hitRadius + l.width / 2
            case .sticker, .image:
                return false
            }
        }
        if items.count != before {
            notebook.items = items
            rebuildOverlays()
            onItemsChanged?(items)
            setNeedsDisplay()
        }
    }

    private func distanceToSegment(p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx*dx + dy*dy
        if len2 == 0 { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        return hypot(a.x + t*dx - p.x, a.y + t*dy - p.y)
    }

    // MARK: - Создание

    private func placeSticker(at wp: CGPoint) {
        let size = CGSize(width: 156, height: 130)
        let origin = CGPoint(x: wp.x - size.width / 2, y: wp.y - size.height / 2)
        let sticker = Sticker(color: prefs.stickerColor,
                              frame: CGRect(origin: origin, size: size),
                              text: "")
        var items = notebook.items
        items.append(.sticker(sticker))
        notebook.items = items
        rebuildStickerViews()
        onItemsChanged?(items)
        setNeedsDisplay()
    }

    func placeImage(data: Data, worldSize: CGSize? = nil) {
        let fileName = UUID().uuidString + ".jpg"
        let dir = imagePath(fileName: fileName).deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: imagePath(fileName: fileName))

        let center = worldPoint(from: CGPoint(x: bounds.midX, y: bounds.midY))
        let size = worldSize ?? CGSize(width: 240, height: 180)
        let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        let item = ImageItem(frame: CGRect(origin: origin, size: size), fileName: fileName)

        var items = notebook.items
        items.append(.image(item))
        notebook.items = items
        rebuildImageViews()
        onItemsChanged?(items)
        setNeedsDisplay()
    }

    // MARK: - Публичные штучки

    func setView(x: CGFloat, y: CGFloat, scale: CGFloat) {
        viewX = x; viewY = y; viewScale = max(0.15, min(6, scale))
        rebuildOverlays()
        setNeedsDisplay()
    }

    func applyNotebook(_ nb: Notebook) {
        notebook = nb
        viewX = nb.viewX; viewY = nb.viewY; viewScale = nb.viewScale
        rebuildOverlays()
        setNeedsDisplay()
    }

    func zoomBy(_ factor: CGFloat) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let newScale = max(0.15, min(6, viewScale * factor))
        let wx = (center.x - viewX) / viewScale
        let wy = (center.y - viewY) / viewScale
        viewScale = newScale
        viewX = center.x - wx * newScale
        viewY = center.y - wy * newScale
        rebuildOverlays()
        setNeedsDisplay()
        onViewChanged?(viewX, viewY, viewScale)
    }
}
